import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fastpedia',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  List _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchWikipedia(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://pt.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json'));

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body)['query']['search'];
          _isLoading = false;
          print(
              "Resultados da pesquisa: $_searchResults"); // Debugging: print the search results
        });
      } else {
        setState(() {
          _isLoading = false;
          _searchResults = [];
          print(
              "Falha ao carregar resultados de pesquisa"); // Debugging: print failure message
        });
        throw Exception('Failed to load search results');
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      print('Erro durante a pesquisa: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página de Pesquisa'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Digite sua pesquisa',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _searchWikipedia(value);
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('Nenhum resultado encontrado'));
    } else {
      return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_searchResults[index]['title']),
            subtitle: Text(_searchResults[index]['snippet']
                .replaceAll(RegExp(r'<[^>]*>'), '')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailsPage(
                    pageId: _searchResults[index]['pageid'],
                    title: _searchResults[index]['title'],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }
}

class ArticleDetailsPage extends StatefulWidget {
  final int pageId;
  final String title;

  ArticleDetailsPage({required this.pageId, required this.title});

  @override
  _ArticleDetailsPageState createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends State<ArticleDetailsPage> {
  late Future<Map<String, dynamic>> _articleDetails;

  @override
  void initState() {
    super.initState();
    _articleDetails = _fetchArticleDetails(widget.pageId);
  }

  Future<Map<String, dynamic>> _fetchArticleDetails(int pageId) async {
    final response = await http.get(Uri.parse(
        'https://pt.wikipedia.org/w/api.php?action=query&prop=extracts|pageimages|info&inprop=url&exintro&explaintext&format=json&pageids=$pageId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['query']['pages']['$pageId'];
    } else {
      throw Exception('Failed to load article details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _articleDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Nenhum detalhe encontrado'));
          } else {
            final article = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  if (article['title'] != null)
                    Text(
                      article['title'],
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 20),
                  if (article['extract'] != null)
                    Text(
                      article['extract'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(height: 20),
                  if (article['fullurl'] != null)
                    GestureDetector(
                      onTap: () async {
                        final url = article['fullurl'];
                        if (await canLaunch(url)) {
                          await launch(url);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                      child: Text(
                        "Veja mais informações acessando: ${article['fullurl']}",
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (article['thumbnail'] != null)
                    Image.network(article['thumbnail']['source']),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
