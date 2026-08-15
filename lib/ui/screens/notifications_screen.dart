import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.onOpenDiscover,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final VoidCallback onOpenDiscover;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['Story', 'Community', 'System'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Text(
            'Notifications',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          tabs: tabs.map((e) => Tab(text: e)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: tabs.map((tab) {
              return _NotificationTab(
                tab: tab,
                apiService: widget.apiService,
                onOpenDiscover: widget.onOpenDiscover,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab({
    required this.tab,
    required this.apiService,
    required this.onOpenDiscover,
  });

  final String tab;
  final ApiService apiService;
  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: apiService.fetchNotifications(tab: tab),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 42,
                    color: Color(0xFFA9A9A9),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No updates... yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow your favorite authors and save stories to your library to see updates here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 180,
                    child: FilledButton(
                      onPressed: onOpenDiscover,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brand,
                      ),
                      child: const Text('Discover Stories'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final row = rows[index];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (row['title']?.toString() ?? 'I').substring(0, 1),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['message']?.toString() ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row['created_at']?.toString() ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
