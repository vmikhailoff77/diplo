import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';
import 'movements_database.dart';
import 'products_page.dart';
import 'contractors_page.dart';
import 'documents_menu_page.dart';
import 'login_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _isSyncing = false;
  String _statusText = 'Нажмите кнопку для загрузки';
  int _productCount = 0;
  int _contractorCount = 0;


  // ЗДЕСЬ ВАШ АДРЕС - ЗАМЕНИТЕ!
  final String baseUrl = 'http://192.168.1.217/flutter_order_1C/hs/flutter_1c';

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final productCount = await DatabaseHelper().getProductCount();
    final contractorCount = await DatabaseHelper().getContractorCount();
    setState(() {
      _productCount = productCount;
      _contractorCount = contractorCount;
      if (productCount > 0 || contractorCount > 0) {
        _statusText = 'В базе: товаров $_productCount, контрагентов $_contractorCount';
      }
    });
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _statusText = 'Синхронизация...';
    });

    try {
      // 1. Загружаем товары
      final productsResponse = await http.get(
        Uri.parse('$baseUrl/products'),
      ).timeout(const Duration(seconds: 15));

      if (productsResponse.statusCode == 200) {
        final productsData = json.decode(utf8.decode(productsResponse.bodyBytes));
        await DatabaseHelper().saveProducts(productsData);
      } else {
        throw Exception('Ошибка загрузки товаров: ${productsResponse.statusCode}');
      }

      // 2. Загружаем контрагентов
      final customersResponse = await http.get(
        Uri.parse('$baseUrl/customers'),
      ).timeout(const Duration(seconds: 15));

      if (customersResponse.statusCode == 200) {
        final customersData = json.decode(utf8.decode(customersResponse.bodyBytes));
        await DatabaseHelper().saveContractors(customersData);
      } else {
        throw Exception('Ошибка загрузки контрагентов: ${customersResponse.statusCode}');
      }

      // 3. Загружаем остатки
      final stockResponse = await http.get(
        Uri.parse('$baseUrl/stock'),
      ).timeout(const Duration(seconds: 15));

      if (stockResponse.statusCode == 200) {
        final stockData = json.decode(utf8.decode(stockResponse.bodyBytes));
        await DatabaseHelper().updateStock(stockData);

      } else {
        print('Ошибка загрузки остатков: ${stockResponse.statusCode}');
      }

      // Синхронизация движений для аналитики
      final products = await DatabaseHelper().getProducts();
      int totalMovements = 0;

      for (var product in products) {
        try {
          final movementsResponse = await http.get(
            Uri.parse('$baseUrl/drive?uuid=${product['uuid']}'),
          ).timeout(const Duration(seconds: 15));

          if (movementsResponse.statusCode == 200) {
            final List<dynamic> movements = json.decode(utf8.decode(movementsResponse.bodyBytes));
            await MovementsDatabase().saveMovements(movements);
            totalMovements += movements.length;
          } else if (movementsResponse.statusCode != 404) {
            print(' Ошибка ${movementsResponse.statusCode} для ${product['name']}');
          }
        } catch (e) {
          print(' Ошибка для ${product['name']}: $e');
        }
      }

      await _loadCounts();

      setState(() {
        _isSyncing = false;
        _statusText = 'Синхронизация завершена!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Синхронизация завершена!')),
      );
    } catch (e) {
      print('Ошибка синхронизации: $e');
      setState(() {
        _isSyncing = false;
        _statusText = 'Ошибка: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Складской помощник'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(_isSyncing ? Icons.sync : Icons.sync_outlined),
            onPressed: _isSyncing ? null : _syncData,
            tooltip: 'Синхронизация',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Статус
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    (_productCount > 0 || _contractorCount > 0) ? Icons.check_circle : Icons.info,
                    color: (_productCount > 0 || _contractorCount > 0) ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusText)),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Кнопка синхронизации
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncData,
              icon: Icon(_isSyncing ? Icons.sync : Icons.cloud_download),
              label: Text(_isSyncing ? 'Синхронизация...' : 'Синхронизировать с 1С'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue[700],
              ),
            ),

            const SizedBox(height: 24),

            // Кнопка Номенклатура
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductsPage()),
                  ).then((_) => _loadCounts());
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: Colors.green[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Номенклатура',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_productCount товаров',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка Контрагенты
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContractorsPage()),
                  ).then((_) => _loadCounts());
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: Colors.orange[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.business, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Контрагенты',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_contractorCount записей',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ← НОВАЯ КНОПКА: Документы
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DocumentsMenuPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: Colors.purple[700],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description, size: 28),
                    const SizedBox(width: 12),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Документы',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Создание и просмотр',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}