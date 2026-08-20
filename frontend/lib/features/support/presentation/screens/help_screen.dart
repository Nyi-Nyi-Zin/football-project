import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _FaqItem {
  final String category;
  final String question;
  final String answer;

  const _FaqItem(this.category, this.question, this.answer);
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';

  static const _items = <_FaqItem>[
    _FaqItem('Betting', 'Why did my odds change?',
        'Live odds can move before a bet is accepted. The bet slip will show the updated price and ask you to confirm again when the change affects your selection.'),
    _FaqItem('Betting', 'What happens after a match ends?',
        'The settlement worker evaluates the final match result and updates the bet status and wallet ledger automatically. You can open Bet Details to see the current status.'),
    _FaqItem('Cash-out', 'Why is cash-out unavailable?',
        'Cash-out is available only for eligible active single bets during a live match. A quote may expire or change when live odds move, so request a fresh quote and try again.'),
    _FaqItem('Wallet', 'Why is my balance temporarily reserved?',
        'A pending withdrawal or bet stake can reserve funds. Wallet transaction details show the balance before, balance after, reference, and related account information.'),
    _FaqItem('Withdrawal', 'How does a withdrawal payout work?',
        'Choose an eligible Agent and submit a request. Your amount is held while pending. Give the generated payout code to the selected Agent, who completes the atomic settlement.'),
    _FaqItem('Verification', 'Why do I need verification before withdrawal?',
        'Email, phone, and KYC checks protect your account and help keep withdrawals safe. Profile shows which requirement is verified, pending, rejected, or still required.'),
    _FaqItem('Responsible Gaming', 'How can I take a break?',
        'Open Profile → Responsible Gaming to set a daily stake limit, single-bet limit, cool-off period, or self-exclusion. These local controls block bet placement automatically.'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = _items.where((item) {
      final categoryMatch = _category == 'All' || item.category == _category;
      final textMatch = query.isEmpty ||
          item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query);
      return categoryMatch && textMatch;
    }).toList();
    final categories = ['All', ..._items.map((item) => item.category).toSet()];

    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search help topics',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No matching help article. Try another search term.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...visible.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text(item.question,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item.category),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.answer,
                          style: const TextStyle(height: 1.45)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
