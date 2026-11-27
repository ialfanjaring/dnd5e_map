import 'package:flutter/material.dart';

import 'demo_board.dart';
import 'rules_help.dart';

/// Un paso de un manual o tutorial (texto en los dos idiomas y, si hace
/// falta, un tablero de ejemplo).
class GuideStep {
  const GuideStep({
    required this.icon,
    required this.es,
    required this.en,
    required this.bodyEs,
    required this.bodyEn,
    this.scene,
    this.tipEs,
    this.tipEn,
  });

  final IconData icon;
  final String es;
  final String en;
  final String bodyEs;
  final String bodyEn;
  final DemoScene? scene;
  final String? tipEs;
  final String? tipEn;

  String get title => bi(es, en);
  String get body => bi(bodyEs, bodyEn);
  String? get tip => tipEs == null ? null : bi(tipEs!, tipEn ?? tipEs!);
}

/// Pantalla que enseña los pasos uno a uno, con «Anterior» / «Siguiente».
class StepViewerScreen extends StatefulWidget {
  const StepViewerScreen({
    super.key,
    required this.title,
    required this.steps,
    this.color,
    this.initial = 0,
  });

  /// Paso por el que se abre
  final int initial;

  final String title;
  final List<GuideStep> steps;
  final Color? color;

  @override
  State<StepViewerScreen> createState() => _StepViewerScreenState();
}

class _StepViewerScreenState extends State<StepViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    _pages.animateToPage(i,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.steps.length;
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Índice de pasos
          PopupMenuButton<int>(
            tooltip: bi('Índice', 'Contents'),
            icon: const Icon(Icons.list),
            onSelected: _go,
            itemBuilder: (_) => [
              for (var k = 0; k < n; k++)
                PopupMenuItem(
                  value: k,
                  child: Text('${k + 1}. ${widget.steps[k].title}'),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_i + 1) / n,
              color: color,
              backgroundColor: color.withOpacity(0.15),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: n,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (context, i) => _StepPage(
                  step: widget.steps[i],
                  index: i,
                  total: n,
                  color: color,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _i == 0 ? null : () => _go(_i - 1),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(bi('Anterior', 'Back')),
                  ),
                  const Spacer(),
                  Text('${_i + 1} / $n'),
                  const Spacer(),
                  _i == n - 1
                      ? FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: Text(bi('Terminar', 'Finish')),
                        )
                      : FilledButton.icon(
                          onPressed: () => _go(_i + 1),
                          icon: const Icon(Icons.chevron_right),
                          label: Text(bi('Siguiente', 'Next')),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.index,
    required this.total,
    required this.color,
  });

  final GuideStep step;
  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tip = step.tip;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(step.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${bi('Paso', 'Step')} ${index + 1}',
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                        Text(
                          step.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(step.body, style: const TextStyle(fontSize: 15, height: 1.4)),
              if (step.scene != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520, maxHeight: 340),
                    child: DemoBoard(scene: step.scene!),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    bi('Ejemplo', 'Example'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
              if (tip != null) ...[
                const SizedBox(height: 14),
                Card(
                  color: color.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tip)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
