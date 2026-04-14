import 'package:flutter/material.dart';
import 'stock_distribution_report.dart';
import 'stock_dynamics_report.dart';
import 'analytics_report.dart';

class AnalyticsMenuPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const AnalyticsMenuPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Аналитика: ${product['name']}'),
        backgroundColor: Colors.green[700],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildReportCard(
            title: 'Остатки на складе',
            icon: Icons.pie_chart,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDistributionReport(product: product),
                ),
              );
            },
          ),
          _buildReportCard(
            title: 'Динамика остатков',
            icon: Icons.show_chart,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDynamicsReport(product: product),
                ),
              );
            },
          ),
          _buildReportCard(
            title: 'Приход/Расход',
            icon: Icons.swap_horiz,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalyticsReport(product: product),
                ),
              );
            },
          ),
          _buildReportCard(
            title: 'Топ продаж',
            icon: Icons.trending_up,
            color: Colors.purple,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Отчет в разработке')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}