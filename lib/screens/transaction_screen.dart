import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController minAmountController = TextEditingController();
  final TextEditingController maxAmountController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> transactionStream;

  String selectedType = 'all';
  String selectedRange = 'all';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    transactionStream = FirebaseFirestore.instance
        .collection("transactions")
        .where("userId", isEqualTo: uid)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    minAmountController.dispose();
    maxAmountController.dispose();
    super.dispose();
  }

  void showClearDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Clear Transactions"),
          content: const Text(
            "Are you sure you want to delete all transactions?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await clearTransactions();

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> clearTransactions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = await FirebaseFirestore.instance
        .collection("transactions")
        .where("userId", isEqualTo: uid)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  void showTransactionDetails(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    final dateText = timestamp is Timestamp
        ? _formatDateTime(timestamp.toDate())
        : 'Pending timestamp';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Transaction Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Type"),
                subtitle: Text(
                  _formatTypeLabel((data['type'] ?? '').toString()),
                ),
              ),
              ListTile(
                title: const Text("Amount"),
                subtitle: Text("\$${(data['amount'] ?? 0).toString()}"),
              ),
              ListTile(
                title: const Text("User"),
                subtitle: Text((data['username'] ?? '').toString()),
              ),
              if (data['to'] != null)
                ListTile(
                  title: const Text("To"),
                  subtitle: Text(data['to'].toString()),
                ),
              if (data['from'] != null)
                ListTile(
                  title: const Text("From"),
                  subtitle: Text(data['from'].toString()),
                ),
              if (data['billType'] != null)
                ListTile(
                  title: const Text("Bill Type"),
                  subtitle: Text(data['billType'].toString()),
                ),
              ListTile(title: const Text("Date"), subtitle: Text(dateText)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final query = searchController.text.trim().toLowerCase();
    final minAmount = double.tryParse(minAmountController.text.trim());
    final maxAmount = double.tryParse(maxAmountController.text.trim());
    final now = DateTime.now();

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['type'] ?? '').toString();
      final username = (data['username'] ?? '').toString().toLowerCase();
      final fromName = (data['from'] ?? '').toString().toLowerCase();
      final toName = (data['to'] ?? '').toString().toLowerCase();
      final billType = (data['billType'] ?? '').toString().toLowerCase();
      final amount = ((data['amount'] ?? 0) as num).toDouble();
      final timestamp = data['timestamp'];

      if (selectedType != 'all' && type != selectedType) {
        return false;
      }

      if (minAmount != null && amount < minAmount) {
        return false;
      }

      if (maxAmount != null && amount > maxAmount) {
        return false;
      }

      if (selectedRange != 'all' && timestamp is Timestamp) {
        final date = timestamp.toDate();
        final days = selectedRange == '7d' ? 7 : 30;
        if (date.isBefore(now.subtract(Duration(days: days)))) {
          return false;
        }
      }

      if (query.isEmpty) {
        return true;
      }

      final matchesText =
          username.contains(query) ||
          fromName.contains(query) ||
          toName.contains(query) ||
          billType.contains(query) ||
          _formatTypeLabel(type).toLowerCase().contains(query);

      final matchesAmount = amount.toStringAsFixed(2).contains(query);

      return matchesText || matchesAmount;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      selectedType = 'all';
      selectedRange = 'all';
      searchController.clear();
      minAmountController.clear();
      maxAmountController.clear();
    });
  }

  String _formatTypeLabel(String type) {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'withdraw':
        return 'Withdraw';
      case 'transfer_sent':
        return 'Transfer Sent';
      case 'transfer_received':
        return 'Transfer Received';
      case 'bill_payment':
        return 'Bill Payment';
      default:
        return type.replaceAll('_', ' ').trim().isEmpty
            ? 'Unknown'
            : type.replaceAll('_', ' ');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}  $hour:$minute $suffix';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'deposit':
        return Icons.south_rounded;
      case 'withdraw':
        return Icons.north_rounded;
      case 'transfer_sent':
        return Icons.call_made_rounded;
      case 'transfer_received':
        return Icons.call_received_rounded;
      case 'bill_payment':
        return Icons.receipt_long_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'deposit':
        return const Color(0xFF3CE6B0);
      case 'withdraw':
        return const Color(0xFFFF7E79);
      case 'transfer_sent':
        return const Color(0xFF7AA8FF);
      case 'transfer_received':
        return const Color(0xFF7BFFD4);
      case 'bill_payment':
        return const Color(0xFFE6C15A);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Transactions"),
        actions: [
          const TopRightBackButton(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: showClearDialog,
          ),
        ],
      ),
      body: AuroraBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: transactionStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            final filteredDocs = _applyFilters(docs);
            final visibleAmount = filteredDocs.fold<double>(
              0,
              (runningTotal, doc) =>
                  runningTotal +
                  (((doc.data() as Map<String, dynamic>)['amount'] ?? 0) as num)
                      .toDouble(),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth > 780
                    ? 740.0
                    : constraints.maxWidth;
                final filterFieldWidth = contentWidth > 620
                    ? (contentWidth - 12) / 2
                    : contentWidth;

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 72, bottom: 20),
                      children: [
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transaction Explorer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Search by recipient, sender, bill type, amount, or narrow the list by transaction type and amount range.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: searchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search_rounded),
                                  labelText: 'Search transactions',
                                  hintText: 'Deposit, Ahmed, Electricity, 250',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: filterFieldWidth,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedType,
                                      dropdownColor: const Color(0xFF17333B),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text('All Types'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'deposit',
                                          child: Text('Deposits'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'withdraw',
                                          child: Text('Withdrawals'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'transfer_sent',
                                          child: Text('Transfer Sent'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'transfer_received',
                                          child: Text('Transfer Received'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'bill_payment',
                                          child: Text('Bill Payments'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedType = value ?? 'all';
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Transaction Type',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: filterFieldWidth,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedRange,
                                      dropdownColor: const Color(0xFF17333B),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text('All Dates'),
                                        ),
                                        DropdownMenuItem(
                                          value: '7d',
                                          child: Text('Last 7 Days'),
                                        ),
                                        DropdownMenuItem(
                                          value: '30d',
                                          child: Text('Last 30 Days'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedRange = value ?? 'all';
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Date Range',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: filterFieldWidth,
                                    child: TextField(
                                      controller: minAmountController,
                                      onChanged: (_) => setState(() {}),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'),
                                        ),
                                      ],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: const InputDecoration(
                                        prefixText: '\$ ',
                                        labelText: 'Minimum Amount',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: filterFieldWidth,
                                    child: TextField(
                                      controller: maxAmountController,
                                      onChanged: (_) => setState(() {}),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'),
                                        ),
                                      ],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: const InputDecoration(
                                        prefixText: '\$ ',
                                        labelText: 'Maximum Amount',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _summaryPill(
                                    Icons.filter_alt_rounded,
                                    '${filteredDocs.length} shown',
                                  ),
                                  _summaryPill(
                                    Icons.attach_money_rounded,
                                    'Visible \$${visibleAmount.toStringAsFixed(2)}',
                                  ),
                                  TextButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: const Text('Reset Filters'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filteredDocs.isEmpty)
                          FrostedPanel(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.travel_explore_rounded,
                                    size: 42,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No matching transactions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try a broader search or reset your filters.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...List.generate(filteredDocs.length, (index) {
                            final data =
                                filteredDocs[index].data()
                                    as Map<String, dynamic>;
                            final type = (data['type'] ?? '').toString();
                            final timestamp = data['timestamp'];
                            final dateText = timestamp is Timestamp
                                ? _formatDateTime(timestamp.toDate())
                                : 'Pending timestamp';
                            final accent = _colorForType(type);
                            final directionLabel = data['to'] != null
                                ? 'To ${data['to']}'
                                : data['from'] != null
                                ? 'From ${data['from']}'
                                : data['billType'] != null
                                ? data['billType'].toString()
                                : data['username'].toString();

                            return _AnimatedTransactionCard(
                              index: index,
                              child: Card(
                                color: Colors.transparent,
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                child: FrostedPanel(
                                  padding: const EdgeInsets.all(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      showTransactionDetails(data);
                                    },
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: accent.withValues(
                                              alpha: 0.18,
                                            ),
                                            border: Border.all(
                                              color: accent.withValues(
                                                alpha: 0.38,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            _iconForType(type),
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatTypeLabel(type),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                directionLabel,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.82),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                dateText,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.58),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '\$${(((data['amount'] ?? 0) as num).toDouble()).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 15,
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _summaryPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7BFFD4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTransactionCard extends StatefulWidget {
  const _AnimatedTransactionCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_AnimatedTransactionCard> createState() =>
      _AnimatedTransactionCardState();
}

class _AnimatedTransactionCardState extends State<_AnimatedTransactionCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(-0.16, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
