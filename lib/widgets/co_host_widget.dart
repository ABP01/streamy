import 'package:flutter/material.dart';

import '../models/co_host.dart';
import '../services/co_host_service.dart';

class CoHostWidget extends StatefulWidget {
  final String liveId;
  final bool isHost;
  final VoidCallback? onCoHostChanged;

  const CoHostWidget({
    super.key,
    required this.liveId,
    required this.isHost,
    this.onCoHostChanged,
  });

  @override
  State<CoHostWidget> createState() => _CoHostWidgetState();
}

class _CoHostWidgetState extends State<CoHostWidget> {
  List<CoHost> _coHosts = [];
  List<CoHostRequest> _pendingRequests = [];
  CoHostRequest? _myPendingRequest;
  bool _isCoHost = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCoHostData();
    _listenToCoHostChanges();
  }

  void _loadCoHostData() async {
    setState(() => _isLoading = true);

    try {
      // Charger les co-hosts actifs
      _coHosts = await CoHostService.getActiveCoHosts(widget.liveId);

      // Si c'est l'hôte, charger les demandes en attente
      if (widget.isHost) {
        _pendingRequests = await CoHostService.getCoHostRequests(widget.liveId);
      } else {
        // Si c'est un visiteur, vérifier s'il est co-host ou a une demande en attente
        _isCoHost = await CoHostService.isCoHost(widget.liveId);
        _myPendingRequest = await CoHostService.getPendingRequest(
          widget.liveId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToCoHostChanges() {
    // Écouter les changements de co-hosts
    CoHostService.getActiveCoHostsStream(widget.liveId).listen((coHosts) {
      if (mounted) {
        setState(() => _coHosts = coHosts);
        widget.onCoHostChanged?.call();
      }
    });

    // Si c'est l'hôte, écouter les nouvelles demandes
    if (widget.isHost) {
      CoHostService.getCoHostRequestsStream(widget.liveId).listen((requests) {
        if (mounted) {
          setState(() => _pendingRequests = requests);
        }
      });
    }
  }

  Future<void> _requestCoHost() async {
    try {
      setState(() => _isLoading = true);
      await CoHostService.requestCoHost(liveId: widget.liveId);
      _loadCoHostData(); // Recharger les données

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de co-host envoyée !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_myPendingRequest == null) return;

    try {
      setState(() => _isLoading = true);
      await CoHostService.cancelCoHostRequest(_myPendingRequest!.id);
      _loadCoHostData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande annulée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveCoHost() async {
    try {
      setState(() => _isLoading = true);
      await CoHostService.leaveCoHost(widget.liveId);
      _loadCoHostData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez quitté le co-host'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    try {
      setState(() => _isLoading = true);
      await CoHostService.respondToCoHostRequest(
        requestId: requestId,
        accept: accept,
      );
      _loadCoHostData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Co-host accepté !' : 'Demande refusée'),
            backgroundColor: accept ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeCoHost(String coHostUserId) async {
    try {
      setState(() => _isLoading = true);
      await CoHostService.removeCoHost(
        liveId: widget.liveId,
        coHostUserId: coHostUserId,
      );
      _loadCoHostData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Co-host retiré'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Afficher les co-hosts actifs
        if (_coHosts.isNotEmpty) ...[
          _buildCoHostsList(),
          const SizedBox(height: 16),
        ],

        // Afficher les demandes en attente pour l'hôte
        if (widget.isHost && _pendingRequests.isNotEmpty) ...[
          _buildPendingRequestsList(),
          const SizedBox(height: 16),
        ],

        // Boutons d'action pour les visiteurs
        if (!widget.isHost) _buildVisitorActions(),

        // Indicateur de chargement
        if (_isLoading) const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildCoHostsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Co-hosts (${_coHosts.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_coHosts.map((coHost) => _buildCoHostItem(coHost))),
        ],
      ),
    );
  }

  Widget _buildCoHostItem(CoHost coHost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundImage: coHost.userAvatar != null
                ? NetworkImage(coHost.userAvatar!)
                : null,
            child: coHost.userAvatar == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 12),

          // Nom
          Expanded(
            child: Text(
              coHost.userName,
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Bouton retirer (seulement pour l'hôte)
          if (widget.isHost)
            IconButton(
              onPressed: () => _removeCoHost(coHost.userId),
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              iconSize: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Demandes de co-host (${_pendingRequests.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_pendingRequests.map((request) => _buildRequestItem(request))),
        ],
      ),
    );
  }

  Widget _buildRequestItem(CoHostRequest request) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundImage: request.requesterAvatar != null
                ? NetworkImage(request.requesterAvatar!)
                : null,
            child: request.requesterAvatar == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 12),

          // Nom
          Expanded(
            child: Text(
              request.requesterName,
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Boutons accepter/refuser
          IconButton(
            onPressed: () => _respondToRequest(request.id, true),
            icon: const Icon(Icons.check_circle, color: Colors.green),
            iconSize: 20,
          ),
          IconButton(
            onPressed: () => _respondToRequest(request.id, false),
            icon: const Icon(Icons.cancel, color: Colors.red),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorActions() {
    if (_isCoHost) {
      // L'utilisateur est déjà co-host
      return ElevatedButton.icon(
        onPressed: _leaveCoHost,
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Quitter le co-host'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      );
    } else if (_myPendingRequest != null) {
      // L'utilisateur a une demande en attente
      return Column(
        children: [
          const Text(
            'Demande en attente...',
            style: TextStyle(color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _cancelRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annuler la demande'),
          ),
        ],
      );
    } else {
      // L'utilisateur peut faire une demande
      return ElevatedButton.icon(
        onPressed: _requestCoHost,
        icon: const Icon(Icons.person_add),
        label: const Text('Demander à être co-host'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
        ),
      );
    }
  }
}
