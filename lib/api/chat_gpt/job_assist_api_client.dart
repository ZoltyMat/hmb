import '../../ai/ai_provider.dart';
import '../../ai/ai_provider_factory.dart';

class JobAssistResult {
  final String summary;
  final String description;
  final List<String> tasks;

  JobAssistResult({
    required this.summary,
    required this.description,
    required this.tasks,
  });
}

class TaskItemAssistSuggestion {
  final String description;
  final String category;
  final double quantity;
  final double unitCost;
  final String supplier;
  final String notes;

  TaskItemAssistSuggestion({
    required this.description,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.supplier,
    required this.notes,
  });
}

class JobAssistApiClient {
  /// Accepts an optional [AIProvider] for testing; otherwise uses the factory.
  JobAssistApiClient({AIProvider? provider}) : _injected = provider;

  final AIProvider? _injected;

  Future<JobAssistResult?> analyzeDescription(String description) async {
    final provider = _injected ?? await AIProviderFactory.create();
    if (provider == null) {
      return null;
    }

    const systemPrompt =
        'You help a handyman app. Return JSON only with keys: '
        'summary (short job title, <= 60 chars), description '
        '(short clear job description, <= 280 chars), and tasks '
        '(array of short task titles). Use high-level, billable '
        'task outcomes only. Do not break a single activity into '
        'step-by-step subtasks. Prefer 3-6 tasks total.';

    final parsed = await provider.extractStructured(
      description,
      systemPrompt: systemPrompt,
    );

    final summary = (parsed['summary'] as String?)?.trim() ?? '';
    final extractedDescription =
        (parsed['description'] as String?)?.trim() ?? '';
    final tasks = (parsed['tasks'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return JobAssistResult(
      summary: summary,
      description: extractedDescription,
      tasks: normalizeJobAssistTasks(tasks),
    );
  }

  Future<List<TaskItemAssistSuggestion>?> expandTaskToItems({
    required String jobSummary,
    required String jobDescription,
    required String taskName,
    required String taskDescription,
  }) async {
    final provider = _injected ?? await AIProviderFactory.create();
    if (provider == null) {
      return null;
    }

    const systemPrompt =
        'You help a handyman estimator. Return JSON only with key '
        '"items" which is an array. Each item must have: description '
        '(string), category (one of labour|material|tool|consumable), '
        'quantity (number), unitCost (number in AUD, 0 if unknown), '
        'supplier (string, empty if unknown), notes (string). '
        'Prefer 3-8 practical items and include likely materials with '
        'ballpark unit costs where reasonable.';

    final parsed = await provider.extractStructured(
      'Job summary: $jobSummary\n'
      'Job description: $jobDescription\n'
      'Task: $taskName\n'
      'Task description: $taskDescription',
      systemPrompt: systemPrompt,
    );

    final rawItems = parsed['items'] as List<dynamic>? ?? const [];

    return rawItems
        .map((item) {
          final map = item as Map<String, dynamic>;
          return TaskItemAssistSuggestion(
            description: (map['description'] as String? ?? '').trim(),
            category: (map['category'] as String? ?? 'material').trim(),
            quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
            unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
            supplier: (map['supplier'] as String? ?? '').trim(),
            notes: (map['notes'] as String? ?? '').trim(),
          );
        })
        .where((item) => item.description.isNotEmpty)
        .toList();
  }
}

List<String> normalizeJobAssistTasks(
  List<String> rawTasks, {
  int maxTasks = 6,
}) {
  final unique = <String>{};
  for (final raw in rawTasks) {
    final task = raw.trim();
    if (task.isEmpty) {
      continue;
    }
    final normalizedKey = task.toLowerCase();
    if (unique.any((e) => e.toLowerCase() == normalizedKey)) {
      continue;
    }
    unique.add(task);
    if (unique.length >= maxTasks) {
      break;
    }
  }
  return unique.toList();
}
