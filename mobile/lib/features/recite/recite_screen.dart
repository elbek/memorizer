import 'package:flutter/material.dart';
import 'package:memorizer/features/schedule/today_screen.dart';
import 'package:memorizer/features/pools/pools_screen.dart';

class ReciteScreen extends StatelessWidget {
  const ReciteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recite'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Schedule'),
              Tab(text: 'Pools'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TodayScreen(embedded: true),
            PoolsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
