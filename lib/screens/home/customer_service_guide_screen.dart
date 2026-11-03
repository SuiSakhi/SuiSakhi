import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CustomerServiceGuideScreen extends StatefulWidget {
  const CustomerServiceGuideScreen({super.key});

  @override
  State<CustomerServiceGuideScreen> createState() =>
      _CustomerServiceGuideScreenState();
}

class _CustomerServiceGuideScreenState
    extends State<CustomerServiceGuideScreen> {
  static const _starterSuggestions = [
    'Shop sarees',
    'Track my order',
    'Quick alteration',
    'Garment care',
    'Rent an outfit',
    'Bulk order',
  ];

  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_GuideMessage> _messages = [
    const _GuideMessage(
      text:
          'Hello! Tell me what you need and I’ll take you to the right place in SuiSakhi.',
      fromCustomer: false,
      suggestions: _starterSuggestions,
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    _inputController.clear();
    _inputFocusNode.unfocus();
    final resolution = _resolveQuery(query);
    if (resolution.action case final action?) {
      context.push(action.route);
      return;
    }

    setState(() {
      _messages.add(_GuideMessage(text: query, fromCustomer: true));
      _messages.add(resolution);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _GuideMessage _resolveQuery(String query) {
    final text = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (_hasAny(normalized, const [
      'track',
      'order status',
      'where is my order',
      'my order',
      'delivery status',
      'shipment',
    ])) {
      return _actionReply(
        'I can help you check your order updates.',
        'View my orders',
        '/customer-orders',
      );
    }

    if (_hasAny(normalized, const [
      'support',
      'helpdesk',
      'help desk',
      'complaint',
      'talk to someone',
    ])) {
      return _actionReply(
        'You can contact the SuiSakhi support team here.',
        'Contact support',
        '/customer-help-support',
      );
    }

    if (_hasAny(normalized, const [
      'rent',
      'rental',
      'hire an outfit',
      'borrow an outfit',
    ])) {
      return _actionReply(
        'I’ll open the outfit rental request form.',
        'Request a rental',
        '/dress-rental-request',
      );
    }

    if (_hasAny(normalized, const [
      'bulk order',
      'bulk booking',
      'group outfits',
      'many outfits',
      'wedding package',
      'event package',
      'bulk',
    ])) {
      return _actionReply(
        'I’ll open the request form for group and bulk outfits.',
        'Make a bulk request',
        '/bulk-orders',
      );
    }

    if (_hasAny(normalized, const [
      'laundry',
      'wash',
      'dry clean',
      'dry-clean',
      'iron',
      'garment care',
      'clean my clothes',
    ])) {
      return _actionReply(
        'I’ll take you to Garment Care services.',
        'Open Garment Care',
        '/garment-care',
      );
    }

    if (_hasAny(normalized, const [
      'quick fix',
      'alteration',
      'alter',
      'repair',
      'button',
      'zip',
      'hemming',
    ])) {
      return _actionReply(
        'I’ll show you Quick Care and alteration services.',
        'Open Quick Care',
        '/quick-fix',
      );
    }

    if (_hasAny(normalized, const [
      'measurement',
      'measurements',
      'my size',
      'body size',
    ])) {
      return _actionReply(
        'I’ll open your measurement tools.',
        'Open measurements',
        '/measurements',
      );
    }

    if (_hasAny(normalized, const [
      'wishlist',
      'wish list',
      'saved item',
      'saved product',
      'favorites',
      'favourites',
    ])) {
      return _actionReply(
        'I’ll open your saved items.',
        'View saved items',
        '/wishlist',
      );
    }

    if (_hasAny(normalized, const ['offer', 'offers', 'discount', 'coupon'])) {
      return _actionReply(
        'I’ll show you current offers and membership details.',
        'View offers',
        '/offers',
      );
    }

    if (_hasAny(normalized, const [
      'design my',
      'design a',
      'custom design',
      'create a design',
    ])) {
      return _actionReply(
        'Let’s explore dress design ideas.',
        'Explore designs',
        '/smart-style-ideas',
      );
    }

    if (_hasAny(normalized, const [
      'tailor',
      'tailoring',
      'stitch for me',
      'stitch my',
      'custom stitch',
      'sew for me',
    ])) {
      return _actionReply(
        'I’ll open the custom tailoring flow.',
        'Start custom tailoring',
        '/designer?entry=order',
      );
    }

    final shopRoute = _shopRouteFor(normalized);
    if (shopRoute != null) {
      final product = shopRoute.searchTerm;
      return _actionReply(
        product == null
            ? 'I’ll open the Fashion Store for you.'
            : 'I’ll search the Fashion Store for $product.',
        product == null ? 'Open Fashion Store' : 'Browse $product',
        shopRoute.route,
      );
    }

    return const _GuideMessage(
      text:
          'I’m not sure which page you need yet. Try one of these, or describe the product or service in a few words.',
      fromCustomer: false,
      suggestions: _starterSuggestions,
    );
  }

  _ShopRoute? _shopRouteFor(String query) {
    const productTerms = <String, String>{
      'saree': 'saree',
      'sari': 'saree',
      'kurti': 'kurti',
      'lehenga': 'lehenga',
      'blouse': 'blouse',
      'gown': 'gown',
      'suit': 'suit',
      'dress': 'dress',
      'sherwani': 'sherwani',
      'western wear': 'western wear',
      'office wear': 'office wear',
      'party wear': 'party wear',
      'festive wear': 'festive',
      'accessories': 'accessories',
      'jewellery': 'accessories',
      'jewelry': 'accessories',
      'fabric': 'fabric',
      'fabrics': 'fabric',
      'kids wear': 'kids_fashion',
      'kids clothes': 'kids_fashion',
    };

    for (final entry in productTerms.entries) {
      if (!_hasAny(query, [entry.key])) continue;
      final term = entry.value;
      final category = switch (term) {
        'accessories' => 'accessories',
        'fabric' => 'fabric',
        'kids_fashion' => 'kids_fashion',
        _ => 'ready_to_wear',
      };
      final searchTerm = term == 'kids_fashion' ? null : term;
      return _ShopRoute(
        route: Uri(
          path: '/shop-explore',
          queryParameters: {
            'category': category,
            ...?_searchQueryParameter(searchTerm),
          },
        ).toString(),
        searchTerm: searchTerm,
      );
    }

    if (_hasAny(query, const [
      'shop',
      'buy',
      'purchase',
      'fashion store',
      'readymade',
      'ready made',
      'clothes',
      'clothing',
      'outfit',
      'browse brands',
    ])) {
      return const _ShopRoute(route: '/shop-explore?category=ready_to_wear');
    }
    return null;
  }

  bool _hasAny(String text, List<String> phrases) => phrases.any(text.contains);

  Map<String, String>? _searchQueryParameter(String? searchTerm) =>
      searchTerm == null ? null : {'q': searchTerm};

  _GuideMessage _actionReply(String text, String label, String route) =>
      _GuideMessage(
        text: text,
        fromCustomer: false,
        action: _GuideAction(label: label, route: route),
      );

  void _openAction(_GuideAction action) {
    context.push(action.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SuiSakhi Guide', style: AppTextStyles.titleMedium),
            Text(
              'Find products, services and orders',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messageBubble(_messages[index]),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _messageBubble(_GuideMessage message) {
    final bubbleColor = message.fromCustomer
        ? AppColors.primary
        : AppColors.surface;
    final textColor = message.fromCustomer
        ? Colors.white
        : AppColors.textPrimary;
    return Align(
      alignment: message.fromCustomer
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(20),
          border: message.fromCustomer
              ? null
              : Border.all(color: AppColors.divider),
          boxShadow: message.fromCustomer
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
            if (message.action case final action?) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openAction(action),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(action.label),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ],
            if (message.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in message.suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _submit(suggestion),
                      side: const BorderSide(color: AppColors.divider),
                      backgroundColor: AppColors.surface,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Try “buy a saree” or “track my order”',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _submit(_inputController.text),
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    ),
  );
}

class _GuideMessage {
  const _GuideMessage({
    required this.text,
    required this.fromCustomer,
    this.action,
    this.suggestions = const [],
  });

  final String text;
  final bool fromCustomer;
  final _GuideAction? action;
  final List<String> suggestions;
}

class _GuideAction {
  const _GuideAction({required this.label, required this.route});

  final String label;
  final String route;
}

class _ShopRoute {
  const _ShopRoute({required this.route, this.searchTerm});

  final String route;
  final String? searchTerm;
}
