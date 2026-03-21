import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> notifications = [];

  // For Android emulator use 10.0.2.2
  final String baseUrl = 'http://10.0.2.2:5000';

  // TEMP ONLY FOR TESTING:
  // paste the token of the logged-in user who should receive notifications
  final String token = 'PASTE_USER_TOKEN_HERE';

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load notifications: ${response.body}');
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['items'] is List) {
          items = decoded['items'];
        } else if (decoded['notifications'] is List) {
          items = decoded['notifications'];
        }
      }

      setState(() {
        notifications =
            items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String getTitle(Map<String, dynamic> item) {
    final payload = item['payload'];
    if (payload is Map && payload['title'] != null) {
      return payload['title'].toString();
    }
    return item['type']?.toString() ?? 'Notification';
  }

  String getMessage(Map<String, dynamic> item) {
    final payload = item['payload'];
    if (payload is Map && payload['message'] != null) {
      return payload['message'].toString();
    }
    if (payload is String) {
      try {
        final parsed = jsonDecode(payload);
        if (parsed is Map && parsed['message'] != null) {
          return parsed['message'].toString();
        }
      } catch (_) {}
    }
    return 'No message';
  }

  String getTime(Map<String, dynamic> item) {
    return item['created_at']?.toString() ??
        item['createdAt']?.toString() ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadNotifications,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: Builder(
          builder: (context) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (error != null) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (notifications.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No notifications yet')),
                ],
              );
            }

            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(getTitle(item)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(getMessage(item)),
                        const SizedBox(height: 6),
                        Text(
                          getTime(item),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
