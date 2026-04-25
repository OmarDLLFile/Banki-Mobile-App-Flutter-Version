import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/role_navigation.dart';
import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirestoreService firestore = FirestoreService();
  final AuthService authService = AuthService();
  final SecureStorageService storage = SecureStorageService();

  late final Stream<List<UserModel>> usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> transactionsStream;

  bool checkingAccess = true;
  bool hasAccess = false;

  @override
  void initState() {
    super.initState();
    usersStream = firestore.streamUsers();
    transactionsStream = firestore.collectionStream('transactions');
    verifyAdminAccess();
  }

  Future<void> verifyAdminAccess() async {
    final isAdmin = await RoleNavigation.currentUserIsAdmin(); // true, false

    if (!mounted) {
      return;
    }

    setState(() {
      checkingAccess = false;
      hasAccess = isAdmin; // true
    });

    if (!isAdmin) {
      await RoleNavigation.pushAndClearForCurrentUser(context);
    }
  }

  Future<void> updateRole(UserModel user, String nextRole) async {
    await firestore.updateUserRole(user.uid, nextRole);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${user.email} is now $nextRole')));
  }

  Future<void> logout() async {
    await authService.logout();
    await storage.clearSession();

    if (!mounted) {
      return;
    }

    await RoleNavigation.pushAndClearForCurrentUser(context);
  }

  Future<void> showEditUserDialog(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await firestore.updateUserProfile(
                              uid: user.uid,
                              name: nameController.text.trim(),
                              email: emailController.text.trim(),
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Updated ${emailController.text.trim()}',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $e')),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showDeleteUserDialog(UserModel user) async {
    bool deleting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete User'),
              content: Text(
                'Delete ${user.email}? This removes the auth account, user profile, and transactions.',
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: deleting
                      ? null
                      : () async {
                          setDialogState(() {
                            deleting = true;
                          });

                          try {
                            await firestore.softDeleteUser(user.uid);

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.email} soft deleted'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                deleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> toggleUserActive(UserModel user) async {
    final nextValue = !user.isActive;

    await firestore.setUserActive(user.uid, nextValue);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue ? '${user.email} enabled' : '${user.email} disabled',
        ),
      ),
    );
  }

  Map<String, dynamic> buildAdminMetrics(
    List<UserModel> users,
    List<Map<String, dynamic>> transactions,
  ) {
    final activeUsers = users.where((user) => user.isActive && !user.isDeleted);
    final disabledUsers = users.where(
      (user) => !user.isActive || user.isDeleted,
    );
    final admins = users.where((user) => user.isAdmin);

    double totalVolume = 0;
    double totalDeposits = 0;
    double totalWithdrawals = 0;
    double totalTransfers = 0;
    double totalBills = 0;

    for (final transaction in transactions) {
      final amount = ((transaction['amount'] ?? 0) as num).toDouble();
      totalVolume += amount;

      switch (transaction['type']) {
        case 'deposit':
          totalDeposits += amount;
          break;
        case 'withdraw':
          totalWithdrawals += amount;
          break;
        case 'transfer_sent':
          totalTransfers += amount;
          break;
        case 'bill_payment':
          totalBills += amount;
          break;
      }
    }

    return {
      'totalUsers': users.length,
      'activeUsers': activeUsers.length,
      'disabledUsers': disabledUsers.length,
      'admins': admins.length,
      'transactions': transactions.length,
      'totalVolume': totalVolume,
      'deposits': totalDeposits,
      'withdrawals': totalWithdrawals,
      'transfers': totalTransfers,
      'bills': totalBills,
    };
  }

  List<PieChartSectionData> buildAdminSections(Map<String, dynamic> metrics) {
    final deposits = (metrics['deposits'] as double?) ?? 0;
    final withdrawals = (metrics['withdrawals'] as double?) ?? 0;
    final transfers = (metrics['transfers'] as double?) ?? 0;
    final bills = (metrics['bills'] as double?) ?? 0;

    final items = [
      ('Deposits', deposits, const Color(0xFF3CE6B0)),
      ('Withdrawals', withdrawals, const Color(0xFFFF7E79)),
      ('Transfers', transfers, const Color(0xFF7AA8FF)),
      ('Bills', bills, const Color(0xFFE6C15A)),
    ];

    return items
        .map(
          (item) => PieChartSectionData(
            value: item.$2 == 0 ? 0.01 : item.$2,
            color: item.$3,
            radius: 58,
            title: item.$2 == 0 ? '' : item.$1.substring(0, 1),
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        )
        .toList();
  }

  Widget buildUserTile(UserModel user, String currentUid) {
    final isCurrentUser = user.uid == currentUid;
    final nextRole = user.role == UserModel.adminRole
        ? UserModel.userRole
        : UserModel.adminRole;

    return Card(
      color: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      child: FrostedPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF7BFFD4),
            foregroundColor: const Color(0xFF072128),
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
          ),
          title: Text(
            user.name.isEmpty ? user.email : user.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${user.email}\nRole: ${user.role} • ${user.isActive ? 'Active' : 'Disabled'}${user.isDeleted ? ' • Deleted' : ''} • Balance: \$${user.balance.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          isThreeLine: true,
          trailing: isCurrentUser
              ? const Chip(label: Text('You'))
              : PopupMenuButton<String>(
                  color: const Color(0xFF163139),
                  onSelected: (value) {
                    if (value == 'role') {
                      updateRole(user, nextRole);
                      return;
                    }

                    if (value == 'edit') {
                      showEditUserDialog(user);
                      return;
                    }

                    if (value == 'status') {
                      toggleUserActive(user);
                      return;
                    }

                    if (value == 'delete') {
                      showDeleteUserDialog(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit Details'),
                    ),
                    PopupMenuItem<String>(
                      value: 'role',
                      child: Text(
                        nextRole == UserModel.adminRole
                            ? 'Make Admin'
                            : 'Make User',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'status',
                      child: Text(
                        user.isActive ? 'Disable User' : 'Enable User',
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Soft Delete User'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!hasAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          const TopRightBackButton(),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: AuroraBackground(
        child: StreamBuilder<List<UserModel>>(
          stream: usersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load users: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            final users = snapshot.data ?? const <UserModel>[];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: transactionsStream,
              builder: (context, transactionSnapshot) {
                if (transactionSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactionDocs =
                    transactionSnapshot.data?.docs ?? const [];
                final transactions = transactionDocs
                    .map((doc) => doc.data())
                    .toList();
                final metrics = buildAdminMetrics(users, transactions);
                final contentWidth = MediaQuery.of(context).size.width > 860
                    ? 820.0
                    : MediaQuery.of(context).size.width;
                final cardWidth = contentWidth > 620
                    ? (contentWidth - 12) / 2
                    : contentWidth;

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 72, bottom: 16),
                      children: [
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Control Center',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Track user health, transaction mix, and account status before managing individual users.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Analytics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _metricCard(
                                      'Users',
                                      '${metrics['totalUsers']} total',
                                      '${metrics['activeUsers']} active • ${metrics['disabledUsers']} limited',
                                      const Color(0xFF7BFFD4),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _metricCard(
                                      'Admins',
                                      '${metrics['admins']} admin accounts',
                                      '${metrics['transactions']} transactions tracked',
                                      const Color(0xFF7AA8FF),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _metricCard(
                                      'Total Volume',
                                      '\$${(metrics['totalVolume'] as double).toStringAsFixed(2)}',
                                      'All recorded transactions',
                                      const Color(0xFFE6C15A),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _metricCard(
                                      'Operational Risk',
                                      '${metrics['disabledUsers']} restricted users',
                                      'Review disabled or deleted accounts quickly',
                                      const Color(0xFFFF7E79),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 18,
                                runSpacing: 18,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: Container(
                                      height: 250,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 4,
                                          centerSpaceRadius: 54,
                                          sections: buildAdminSections(metrics),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: Column(
                                      children: [
                                        _miniStatRow(
                                          'Deposits',
                                          metrics['deposits'] as double,
                                          const Color(0xFF3CE6B0),
                                        ),
                                        const SizedBox(height: 10),
                                        _miniStatRow(
                                          'Withdrawals',
                                          metrics['withdrawals'] as double,
                                          const Color(0xFFFF7E79),
                                        ),
                                        const SizedBox(height: 10),
                                        _miniStatRow(
                                          'Transfers',
                                          metrics['transfers'] as double,
                                          const Color(0xFF7AA8FF),
                                        ),
                                        const SizedBox(height: 10),
                                        _miniStatRow(
                                          'Bills',
                                          metrics['bills'] as double,
                                          const Color(0xFFE6C15A),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...users.map(
                          (user) => buildUserTile(user, currentUid ?? ''),
                        ),
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

  Widget _metricCard(
    String title,
    String value,
    String subtitle,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
          ),
        ],
      ),
    );
  }

  Widget _miniStatRow(String label, double amount, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
