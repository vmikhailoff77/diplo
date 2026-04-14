import 'package:flutter/material.dart';
import 'documents_list_page.dart';  // ← ДОБАВИТЬ

class DocumentsMenuPage extends StatelessWidget {
  const DocumentsMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы'),
        backgroundColor: Colors.purple[700],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Кнопка 1: Заказ клиента
            _buildDocumentButton(
              context,
              title: 'Заказ клиента',
              subtitle: 'Просмотр заказов от покупателей',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentsListPage(
                      title: 'Заказы клиентов',
                      endpoint: '/orders',
                      color: Colors.blue,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Кнопка 2: Реализация товаров и услуг
            _buildDocumentButton(
              context,
              title: 'Реализация товаров и услуг',
              subtitle: 'Просмотр отгрузок товаров',
              icon: Icons.local_shipping,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentsListPage(
                      title: 'Реализация товаров и услуг',
                      endpoint: '/sales',
                      color: Colors.green,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Кнопка 3: Приходная накладная
            _buildDocumentButton(
              context,
              title: 'Приходная накладная',
              subtitle: 'Просмотр поступления товаров',
              icon: Icons.arrow_downward,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentsListPage(
                      title: 'Приходные накладные',
                      endpoint: '/income',
                      color: Colors.orange,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Кнопка 4: Расходная накладная
            _buildDocumentButton(
              context,
              title: 'Расходная накладная',
              subtitle: 'Просмотр списания товаров',
              icon: Icons.arrow_upward,
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentsListPage(
                      title: 'Расходные накладные',
                      endpoint: '/expense',
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentButton(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}