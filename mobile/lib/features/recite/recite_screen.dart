import 'package:flutter/material.dart';
import 'package:memorizer/features/schedule/today_screen.dart';
import 'package:memorizer/features/schedule/schedule_list_screen.dart';
import 'package:memorizer/features/schedule/calendar_screen.dart';
import 'package:memorizer/features/schedule/reports_screen.dart';
import 'package:memorizer/features/pools/pools_screen.dart';

class ReciteScreen extends StatelessWidget {
  const ReciteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recite'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Schedules'),
              Tab(text: 'Calendar'),
              Tab(text: 'Reports'),
              Tab(text: 'Pools'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TodayScreen(embedded: true),
            ScheduleListScreen(embedded: true),
            CalendarScreen(embedded: true),
            ReportsScreen(embedded: true),
            PoolsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
