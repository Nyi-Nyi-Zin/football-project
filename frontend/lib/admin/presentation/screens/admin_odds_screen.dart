import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_models.dart';
import '../../data/admin_remote_datasource.dart';

class AdminOddsScreen extends ConsumerStatefulWidget {
  const AdminOddsScreen({super.key});

  @override
  ConsumerState<AdminOddsScreen> createState() => _AdminOddsScreenState();
}

class _AdminOddsScreenState extends ConsumerState<AdminOddsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _matchIdController = TextEditingController();
  final _homeController = TextEditingController(text: '2.00');
  final _drawController = TextEditingController(text: '3.00');
  final _awayController = TextEditingController(text: '2.00');
  late Future<List<AdminMatchSummary>> _matchesFuture;
  AdminMatchSummary? _selectedMatch;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _matchesFuture = ref.read(adminDatasourceProvider).getMatches();
  }

  @override
  void dispose() {
    _matchIdController.dispose();
    _homeController.dispose();
    _drawController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  Future<void> _saveOdds() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminDatasourceProvider).updateOdds(
            matchId: _matchIdController.text.trim(),
            homeOdds: double.parse(_homeController.text.trim()),
            drawOdds: double.parse(_drawController.text.trim()),
            awayOdds: double.parse(_awayController.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odds updated and broadcast to clients.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update odds: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateOdds(String? value) {
    final odds = double.tryParse(value?.trim() ?? '');
    if (odds == null || odds <= 1) return 'Enter odds greater than 1.00';
    return null;
  }

  void _selectMatch(AdminMatchSummary? match) {
    setState(() {
      _selectedMatch = match;
      _matchIdController.text = match?.id ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odds Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Match Odds',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Changes are persisted on the backend and broadcast to live sportsbook clients through WebSocket.',
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<AdminMatchSummary>>(
                      future: _matchesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Row(
                            children: [
                              const Expanded(
                                child: Text(
                                    'Could not load matches. Use a match ID below.'),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  _matchesFuture = ref
                                      .read(adminDatasourceProvider)
                                      .getMatches();
                                }),
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          );
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final matches = snapshot.data!;
                        if (matches.isEmpty) {
                          return const Text(
                              'No matches are currently available.');
                        }
                        return DropdownButtonFormField<AdminMatchSummary>(
                          value: _selectedMatch,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select a live fixture',
                            border: OutlineInputBorder(),
                          ),
                          items: matches
                              .map(
                                (match) => DropdownMenuItem(
                                  value: match,
                                  child: Text(
                                    '${match.label} (${match.status})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving ? null : _selectMatch,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matchIdController,
                      decoration: const InputDecoration(
                        labelText: 'Match ID',
                        hintText: 'UUID from the match details or API',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Match ID is required'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 600
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              child: _oddsField(_homeController, 'Home odds'),
                            ),
                            SizedBox(
                              width: width,
                              child: _oddsField(_drawController, 'Draw odds'),
                            ),
                            SizedBox(
                              width: width,
                              child: _oddsField(_awayController, 'Away odds'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveOdds,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.publish),
                        label: Text(_saving ? 'Saving odds...' : 'Update odds'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _oddsField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _validateOdds,
    );
  }
}
