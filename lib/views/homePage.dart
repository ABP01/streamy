import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/live_provider.dart';
import 'auth/auth_page.dart';
import 'live_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) {
          return const AuthPage();
        }
        return Consumer<LiveProvider>(
          builder: (context, liveProvider, _) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Lives'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => auth.signOut(),
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () => liveProvider.fetchLives(),
                child: liveProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : liveProvider.lives.isEmpty
                    ? const Center(child: Text('Aucun live pour le moment.'))
                    : ListView.builder(
                        itemCount: liveProvider.lives.length,
                        itemBuilder: (context, index) {
                          final live = liveProvider.lives[index];
                          return ListTile(
                            title: Text(live['title'] ?? 'Live'),
                            subtitle: Text('Host: ${live['host_id']}'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LivePage(
                                    channelId: live['channel_id'] ?? live['id'],
                                    liveId: live['id'],
                                    isHost: auth.user!.id == live['host_id'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () async {
                  final titleController = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Créer un live'),
                      content: TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre du live',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isNotEmpty) {
                              await liveProvider.createLiveWithChannel(
                                title,
                                auth.user!.id,
                              );
                              if (liveProvider.errorMessage != null) {
                                // Affiche l'erreur si la création échoue
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        liveProvider.errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                // Rafraîchit la liste après création
                                await liveProvider.fetchLives();
                                if (context.mounted) Navigator.pop(context);
                              }
                            }
                          },
                          child: const Text('Créer'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }
}
