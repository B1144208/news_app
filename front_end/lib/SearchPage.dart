import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ChannelDetailPage.dart';
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  final String _channelUrl = '$baseUrl/api/channel';
  final String _eventSortingUrl = '$baseUrl/api/EventSorting';
  final String _multiplePerspectivesUrl = '$baseUrl/api/MultiplePerspectives';

  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final channelResp = await http.get(Uri.parse(_channelUrl));
      final eventResp = await http.get(Uri.parse(_eventSortingUrl));
      final multipleResp = await http.get(Uri.parse(_multiplePerspectivesUrl));

      List<Map<String, dynamic>> results = [];

      if (channelResp.statusCode == 200) {
        final data = json.decode(channelResp.body)['data'];
        for (var item in data) {
          final name = item['channel_name'] ?? '';
          if (name.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({
              'type': 'channel',
              'id': item['channel_id'],
              'title': name,
            });
          }
        }
      }

      if (eventResp.statusCode == 200) {
        final data = json.decode(eventResp.body)['data'];
        for (var item in data) {
          final title = item['eventsorting_title'] ?? '';
          if (title.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({
              'type': 'eventSorting',
              'id': item['eventsorting_id'],
              'title': title,
            });
          }
        }
      }

      if (multipleResp.statusCode == 200) {
        final data = json.decode(multipleResp.body)['data'];
        for (var item in data) {
          final title = item['multipleperspectives_title'] ?? '';
          if (title.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({
              'type': 'multiplePerspectives',
              'id': item['multipleperspectives_id'],
              'title': title,
            });
          }
        }
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    final type = item['type'];
    final id = item['id'];

    if (type == 'channel') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChannelDetailPage(
            channelId: id,
            channelName: item['title'],
          ),
        ),
      );
    } else if (type == 'eventSorting') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventSortingDetailPage(id: id),
        ),
      );
    } else if (type == 'multiplePerspectives') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiplePerspectivesDetailPage(id: id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '輸入關鍵字',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _performSearch,
            ),
          ),
          _isLoading
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  title: Text(item['title']),
                  subtitle: Text(item['type']),
                  onTap: () => _navigateToDetail(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
