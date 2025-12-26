import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'Newpage.dart';

class Shoppage extends StatefulWidget {
  final int productId;
  const Shoppage({Key? key, required this.productId}) : super(key: key);

  @override
  State<Shoppage> createState() => _ShoppageState();
}

class _ShoppageState extends State<Shoppage> {
  int _currentIndex = 0;
  late final NavigationController controller;
  Map<String, dynamic>? product;
  bool isLoading = true;
  bool isAddingToCart = false;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    controller = Get.find<NavigationController>();
    fetchProduct();
  }

  Future<void> fetchProduct() async {
    try {
      final response = await http.get(
        Uri.parse("https://dummyjson.com/products/${widget.productId}"),
      );
      if (response.statusCode == 200) {
        product = json.decode(response.body);
      } else {
        throw Exception("Failed to load product");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading product: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _openImageViewer(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.grey,
          appBar: AppBar(
            backgroundColor: Colors.grey,
            title: const Text(
              "Preview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          body: PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: PageController(initialPage: index),
            builder: (context, i) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[i]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void openCheckout() {
    var options = {
      'key': 'rzp_test_RAJV8WSouSWp6g',
      'amount': (product!['price'] * 100).toInt(),
      'name': 'Check Out',
      'description': 'Payment for your order',
      'prefill': {
        'contact': '9999999999',
        'email': 'test@gmail.com',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("SUCCESS: ${response.paymentId}")),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("ERROR: ${response.code} | ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("EXTERNAL WALLET: ${response.walletName}")),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final w = size.width;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (product == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Failed to load product."),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: fetchProduct,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final List<String> images =
    (product!['images'] is List && product!['images'].isNotEmpty)
        ? List<String>.from(product!['images'])
        : [];

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(product!['title'] ?? "Product Details"),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (images.isNotEmpty)
              Column(
                children: [
                  CarouselSlider(
                    options: CarouselOptions(
                      height: h * 0.35,
                      viewportFraction: 1.0,
                      autoPlay: true,
                      onPageChanged: (index, _) =>
                          setState(() => _currentIndex = index),
                    ),
                    items: images.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap: () => _openImageViewer(images, entry.key),
                        child: Image.network(
                          entry.value,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((e) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == e.key
                              ? Colors.black
                              : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

            Padding(
              padding: EdgeInsets.all(w * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product!['title'],
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product!['description'],
                      style:
                      const TextStyle(fontSize: 10, color: Colors.grey)),

                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAddingToCart
                            ? null
                            : () async {
                          setState(() => isAddingToCart = true);

                          final success =
                              await controller.addToCart(
                                  1, product!['id'], 1) ==
                                  true;

                          setState(() => isAddingToCart = false);

                          if (success) Navigator.pop(context);
                        },
                        child: isAddingToCart
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text("Add to Cart"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: openCheckout,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber),
                        child: const Text(
                          "Pay with Razorpay",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
