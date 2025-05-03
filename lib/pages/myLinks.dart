import 'package:flutter/material.dart';
import 'config.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

class MyLinksPage extends StatelessWidget {
  const MyLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Links'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Genel Bilgiler'),
                Tab(text: 'Linkler'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 50),
                      ),
                      SizedBox(height: 16),
                      TextField(
                          decoration: InputDecoration(labelText: 'Ad Soyad')),
                      SizedBox(height: 16),
                      TextField(
                          decoration:
                              InputDecoration(labelText: 'Kullanıcı Adı')),
                      SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(labelText: 'Açıklama'),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(labelText: 'Footer'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 3, // Placeholder for up to 3 links
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: Text('Link ${index + 1}'),
                        subtitle: const Text('https://example.com'),
                        trailing: const Icon(Icons.edit),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
