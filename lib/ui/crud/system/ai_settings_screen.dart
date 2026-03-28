import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:settings_yaml/settings_yaml.dart';

import '../../../design_system/molecules/grouped_list_section.dart';
import '../../../design_system/theme.dart';
import '../../../util/dart/paths.dart';
import '../../../util/flutter/app_title.dart';

/// Supported AI providers.
enum AiProvider {
  openai('OpenAI / ChatGPT'),
  openrouter('OpenRouter'),
  ollama('Ollama (Local)');

  const AiProvider(this.label);
  final String label;

  static AiProvider fromName(String? name) {
    for (final p in values) {
      if (p.name == name) {
        return p;
      }
    }
    return AiProvider.openai;
  }
}

/// Settings keys for AI configuration stored in SettingsYaml.
abstract final class _Keys {
  static const provider = 'ai_provider';
  static const modelOverride = 'ai_model_override';
  static const temperature = 'ai_temperature';
  static const openaiApiKey = 'ai_openai_api_key';
  static const openrouterApiKey = 'ai_openrouter_api_key';
  static const ollamaHost = 'ai_ollama_host';
}

/// iOS-style grouped settings screen for AI provider configuration.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  var _provider = AiProvider.openai;
  final _modelController = TextEditingController();
  var _temperature = 0.7;
  final _openaiKeyController = TextEditingController();
  final _openrouterKeyController = TextEditingController();
  final _ollamaHostController = TextEditingController();

  var _loaded = false;

  @override
  void initState() {
    super.initState();
    setAppTitle('AI Assistant');
    unawaited(_load());
  }

  Future<void> _load() async {
    final settings =
        SettingsYaml.load(pathToSettings: await getSettingsPath());
    setState(() {
      _provider =
          AiProvider.fromName(settings[_Keys.provider] as String?);
      _modelController.text =
          (settings[_Keys.modelOverride] as String?) ?? '';
      final temp = settings[_Keys.temperature];
      if (temp is num) {
        _temperature = temp.toDouble().clamp(0.0, 1.0);
      }
      _openaiKeyController.text =
          (settings[_Keys.openaiApiKey] as String?) ?? '';
      _openrouterKeyController.text =
          (settings[_Keys.openrouterApiKey] as String?) ?? '';
      _ollamaHostController.text =
          (settings[_Keys.ollamaHost] as String?) ?? 'http://localhost:11434';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final settings =
        SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings[_Keys.provider] = _provider.name;
    settings[_Keys.modelOverride] = _modelController.text.trim();
    settings[_Keys.temperature] = _temperature;
    settings[_Keys.openaiApiKey] = _openaiKeyController.text.trim();
    settings[_Keys.openrouterApiKey] =
        _openrouterKeyController.text.trim();
    settings[_Keys.ollamaHost] = _ollamaHostController.text.trim();
    await settings.save();
  }

  Future<void> _setProvider(AiProvider p) async {
    setState(() => _provider = p);
    await _save();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _openaiKeyController.dispose();
    _openrouterKeyController.dispose();
    _ollamaHostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: colors.groupedBackground,
      body: ListView(
        children: [
          const SizedBox(height: HmbSpacing.sm),

          // -- Provider Selection --
          GroupedListSection(
            header: 'Provider',
            footer: 'Choose which AI backend to use for assistant features.',
            children: [
              for (final p in AiProvider.values)
                _ProviderTile(
                  label: p.label,
                  selected: _provider == p,
                  colors: colors,
                  typography: typography,
                  onTap: () => _setProvider(p),
                ),
            ],
          ),

          // -- Model Configuration --
          GroupedListSection(
            header: 'Model Configuration',
            footer: 'Leave model blank to use the provider default.',
            children: [
              _TextFieldRow(
                label: 'Model override',
                controller: _modelController,
                placeholder: 'e.g. gpt-4o, mistral-large',
                colors: colors,
                typography: typography,
                onChanged: (_) => unawaited(_save()),
              ),
              _TemperatureRow(
                value: _temperature,
                colors: colors,
                typography: typography,
                onChanged: (v) {
                  setState(() => _temperature = v);
                  unawaited(_save());
                },
              ),
            ],
          ),

          // -- API Keys --
          GroupedListSection(
            header: 'API Keys',
            footer: 'Keys are stored locally on this device.',
            children: [
              _TextFieldRow(
                label: 'OpenAI key',
                controller: _openaiKeyController,
                placeholder: 'sk-...',
                obscure: true,
                colors: colors,
                typography: typography,
                onChanged: (_) => unawaited(_save()),
              ),
              _TextFieldRow(
                label: 'OpenRouter key',
                controller: _openrouterKeyController,
                placeholder: 'sk-or-...',
                obscure: true,
                colors: colors,
                typography: typography,
                onChanged: (_) => unawaited(_save()),
              ),
              _TextFieldRow(
                label: 'Ollama host',
                controller: _ollamaHostController,
                placeholder: 'http://localhost:11434',
                colors: colors,
                typography: typography,
                onChanged: (_) => unawaited(_save()),
              ),
            ],
          ),

          // -- Usage --
          GroupedListSection(
            header: 'Usage',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HmbSpacing.lg,
                  vertical: HmbSpacing.lg,
                ),
                child: Text(
                  'Token usage statistics coming soon.',
                  style: typography.footnote
                      .copyWith(color: colors.secondaryLabel),
                ),
              ),
            ],
          ),

          const SizedBox(height: HmbSpacing.xxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private row widgets
// ---------------------------------------------------------------------------

/// A radio-style provider selection row with a checkmark on the selected item.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final HmbColors colors;
  final HmbTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HmbSpacing.lg,
              vertical: HmbSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: typography.body.copyWith(color: colors.label),
                  ),
                ),
                if (selected)
                  Icon(
                    CupertinoIcons.checkmark_alt,
                    size: 18,
                    color: colors.systemBlue,
                  ),
              ],
            ),
          ),
        ),
      );
}

/// A labelled text field row for settings input.
class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.label,
    required this.controller,
    required this.colors,
    required this.typography,
    this.placeholder,
    this.obscure = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscure;
  final HmbColors colors;
  final HmbTypography typography;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style:
                  typography.footnote.copyWith(color: colors.secondaryLabel),
            ),
            const SizedBox(height: HmbSpacing.xs),
            CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: obscure,
              onChanged: onChanged,
              style: typography.body.copyWith(color: colors.label),
              placeholderStyle:
                  typography.body.copyWith(color: colors.tertiaryLabel),
              padding: const EdgeInsets.symmetric(
                horizontal: HmbSpacing.sm,
                vertical: HmbSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.groupedBackground,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      );
}

/// Temperature slider row (0.0 – 1.0).
class _TemperatureRow extends StatelessWidget {
  const _TemperatureRow({
    required this.value,
    required this.colors,
    required this.typography,
    required this.onChanged,
  });

  final double value;
  final HmbColors colors;
  final HmbTypography typography;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Temperature',
                  style: typography.footnote
                      .copyWith(color: colors.secondaryLabel),
                ),
                const Spacer(),
                Text(
                  value.toStringAsFixed(2),
                  style: typography.footnote
                      .copyWith(color: colors.secondaryLabel),
                ),
              ],
            ),
            CupertinoSlider(
              value: value,
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Precise',
                  style: typography.caption2
                      .copyWith(color: colors.tertiaryLabel),
                ),
                Text(
                  'Creative',
                  style: typography.caption2
                      .copyWith(color: colors.tertiaryLabel),
                ),
              ],
            ),
          ],
        ),
      );
}
