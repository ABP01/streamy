import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/gift_service.dart';

class GiftShopWidget extends StatefulWidget {
  final String receiverId;
  final String liveId;
  final Function(Gift)? onGiftSent;

  const GiftShopWidget({
    super.key,
    required this.receiverId,
    required this.liveId,
    this.onGiftSent,
  });

  @override
  State<GiftShopWidget> createState() => _GiftShopWidgetState();
}

class _GiftShopWidgetState extends State<GiftShopWidget>
    with TickerProviderStateMixin {
  int _userTokens = 0;
  bool _isLoading = true;
  bool _isSending = false;
  String? _selectedGiftType;
  int _selectedQuantity = 1;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserTokens();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserTokens() async {
    try {
      // Récupérer le solde de tokens de l'utilisateur
      // Pour la démo, on utilise une valeur simulée
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _userTokens = 1250; // Valeur simulée
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendGift() async {
    if (_selectedGiftType == null || _isSending) return;

    final giftConfig = GiftService.giftTypes[_selectedGiftType!]!;
    final totalCost = (giftConfig['cost'] as int) * _selectedQuantity;

    if (_userTokens < totalCost) {
      _showInsufficientTokensDialog();
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final gift = await GiftService.sendGift(
        liveId: widget.liveId,
        receiverId: widget.receiverId,
        giftType: _selectedGiftType!,
        quantity: _selectedQuantity,
      );

      if (gift != null && mounted) {
        setState(() {
          _userTokens -= totalCost;
          _selectedGiftType = null;
          _selectedQuantity = 1;
        });

        // Animation de succès
        _pulseController.forward().then((_) {
          _pulseController.reverse();
        });

        // Callback pour notifier l'envoi du cadeau
        widget.onGiftSent?.call(gift);

        // Fermer le widget après un délai
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cadeau envoyé ! 🎁'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showInsufficientTokensDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Tokens insuffisants',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vous n\'avez pas assez de tokens pour envoyer ce cadeau.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showTokenShop();
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Acheter des tokens'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showTokenShop() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Acheter des tokens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: GiftService.tokenPackages.length,
                  itemBuilder: (context, index) {
                    final package = GiftService.tokenPackages[index];
                    return _buildTokenPackageCard(package);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTokenPackageCard(Map<String, dynamic> package) {
    final tokens = package['tokens'] as int;
    final bonus = package['bonus'] as int;
    final price = package['price'] as double;
    final totalTokens = tokens + bonus;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow[700]!, Colors.orange[500]!],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.token, color: Colors.white, size: 30),
        ),
        title: Text(
          package['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package['description'],
              style: const TextStyle(color: Colors.grey),
            ),
            if (bonus > 0)
              Text(
                '+$bonus tokens bonus!',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton(
              onPressed: () => _purchaseTokens(package['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(60, 30),
              ),
              child: const Text('Acheter', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseTokens(String packageId) async {
    Navigator.pop(context); // Fermer le shop

    // Simuler l'achat
    final success = await GiftService.purchaseTokenPackage(packageId, 'card');

    if (success) {
      await _loadUserTokens(); // Recharger le solde
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tokens achetés avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'achat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Envoyer un cadeau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.token, color: Colors.yellow, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$_userTokens',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _showTokenShop,
                      icon: const Icon(Icons.add, color: Colors.blue),
                      tooltip: 'Acheter des tokens',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grille des cadeaux
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: GiftService.giftTypes.length,
                itemBuilder: (context, index) {
                  final giftType = GiftService.giftTypes.keys.elementAt(index);
                  final giftConfig = GiftService.giftTypes[giftType]!;

                  return _buildGiftCard(giftType, giftConfig);
                },
              ),
            ),
          ),

          // Section quantité et envoi
          if (_selectedGiftType != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Sélecteur de quantité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantité:',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _selectedQuantity > 1
                                ? () => setState(() => _selectedQuantity--)
                                : null,
                            icon: const Icon(Icons.remove),
                            color: Colors.white,
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$_selectedQuantity',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _selectedQuantity < 10
                                ? () => setState(() => _selectedQuantity++)
                                : null,
                            icon: const Icon(Icons.add),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Coût total et bouton d'envoi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_getTotalCost()} tokens',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: ElevatedButton.icon(
                              onPressed: _isSending ? null : _sendGift,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(_isSending ? 'Envoi...' : 'Envoyer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGiftCard(String giftType, Map<String, dynamic> giftConfig) {
    final isSelected = _selectedGiftType == giftType;
    final canAfford = _userTokens >= (giftConfig['cost'] as int);

    return GestureDetector(
      onTap: canAfford
          ? () {
              setState(() {
                _selectedGiftType = isSelected ? null : giftType;
                _selectedQuantity = 1;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              giftConfig['emoji'],
              style: TextStyle(
                fontSize: 40,
                color: canAfford ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              giftConfig['name'],
              style: TextStyle(
                color: canAfford ? Colors.white : Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.token, color: Colors.yellow, size: 16),
                const SizedBox(width: 2),
                Text(
                  '${giftConfig['cost']}',
                  style: TextStyle(
                    color: canAfford ? Colors.white : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalCost() {
    if (_selectedGiftType == null) return 0;
    final giftConfig = GiftService.giftTypes[_selectedGiftType!]!;
    return (giftConfig['cost'] as int) * _selectedQuantity;
  }
}
