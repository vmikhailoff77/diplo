import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'analytics_menu_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _statusText = 'Загрузка...';
  DateTime? _lastUpdate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    setState(() => _isLoading = true);

    try {
      final products = await DatabaseHelper().getProducts();
      final lastUpdate = await DatabaseHelper().getLastUpdateDate('products');

      setState(() {
        _products = products;
        _lastUpdate = lastUpdate;
        _isLoading = false;

        if (products.isEmpty) {
          _statusText = 'Нет товаров. Синхронизируйтесь';
        } else {
          _statusText = '${products.length} товаров';
          if (lastUpdate != null) {
            _statusText += ' (обн. ${_formatDate(lastUpdate)})';
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки: $e';
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      await _loadLocalData();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await DatabaseHelper().searchProducts(query);
      setState(() {
        _products = results;
        _isLoading = false;
        _statusText = 'Найдено: ${results.length} товаров';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка поиска: $e';
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Номенклатура'),
        backgroundColor: Colors.green[700],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по артикулу или названию...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadLocalData();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _search,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                _statusText,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[50],
                child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? const Center(child: Text('Нет данных'))
                  : ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final stock = product['stock'] ?? 0;
                  final unit = product['unit'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        product['name'] ?? 'Без имени',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Артикул: ${product['article'] ?? "—"}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stock > 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  stock > 0 ? Icons.check_circle : Icons.cancel,
                                  size: 12,
                                  color: stock > 0 ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Остаток: $stock $unit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: stock > 0 ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: (product['cod'] != null && product['cod'].isNotEmpty)
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product['cod'],
                          style: const TextStyle(fontSize: 10),
                        ),
                      )
                          : null,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(product['name'] ?? 'Товар'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Артикул', product['article']),
                                _buildDetailRow('Код', product['cod']),
                                _buildDetailRow('Единица измерения', product['unit']),
                                _buildDetailRow(
                                  'Цена',
                                  product['price'] != null
                                      ? '${product['price']} руб.'
                                      : null,
                                ),
                                _buildDetailRow('Поставщик', product['contractor']),
                                const Divider(),
                                _buildDetailRow(
                                  'Остаток',
                                  '$stock $unit',
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AnalyticsMenuPage(product: product,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.analytics),
                                    label: const Text('Перейти к аналитике'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Закрыть'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? '—')),
        ],
      ),
    );
  }
}