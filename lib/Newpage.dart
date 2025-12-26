import 'dart:ui';
import 'dart:io';

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_8/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:badges/badges.dart' as badges;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'ShopPage.dart';



class NavigationController extends GetxController {


  void showSnackBar(String message) {
    Get.snackbar(
      "Cart Updated",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.shopping_cart, color: Colors.white),
    );
  }




  String formatCategoryName(String category) {
    return category
        .split('-')
        .map((word) =>
    word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : "")
        .join(" ");
  }

  var selectedIndex = 0.obs;
  var cart = {}.obs;
  var isCartLoading = false.obs;

  var products = <dynamic>[].obs;
  var fullCategories = [].obs;
  var posts = <dynamic>[].obs;
  var categories = <String>[].obs;
  var slugs = <String>[].obs;
  var selectedCategory = 'all'.obs;
  var isInitialLoad = true.obs;
  var isCategoryLoading = false.obs;
  var isProductLoading = false.obs;
  var userInitiatedSearch = false.obs;
  var noResultsFound = false.obs;

  void removeFromCart(int productId) {
    cart['products'].removeWhere((item) => item['id'] == productId);

    // 🔥 update totalQuantity dynamically
    cart['totalQuantity'] = (cart['products'] as List)
        .fold(0, (sum, item) => sum + (item['quantity'] as int));

    cart.refresh(); // trigger Obx updates (UI + badge)
  }


  @override
  void onInit() {
    super.onInit();
    fetchCategories();
    fetchInitialProducts();
  }

  void updateCartQuantity(int productId, int newQuantity) {
    if (cart['products'] == null) return;

    final List products = List.from(cart['products']);
    final index = products.indexWhere((item) => item['id'] == productId);

    if (index >= 0) {
      products[index]['quantity'] = newQuantity;

      // ✅ Update total quantity
      final totalQty = products.fold<int>(
        0,
            (sum, item) => sum + (item['quantity'] as int),
      );

      cart['products'] = products;
      cart['totalQuantity'] = totalQty;

      cart.refresh();

    }
  }


  // 🔹 Navigation between tabs
  void changePage(int index) {
    selectedIndex.value = index;

    if (index == 0 && posts.isEmpty) {
      fetchInitialProducts();
    }

    if (index == 4) {
      fetchCart(1);
    }
  }

  // 🔹 Initial Products
  Future<void> fetchInitialProducts() async {
    isInitialLoad.value = true;
    final url = Uri.parse('https://dummyjson.com/products?limit=1000');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        posts.assignAll(data["products"]);
        log("✅ Initial Products Loaded: ${posts.length}");
      }
    } catch (e) {
      log("❌ Exception: $e");
    } finally {
      isInitialLoad.value = false;
    }
  }

  // 🔹 Categories
  Future<void> fetchCategories() async {
    isCategoryLoading.value = true;
    final url = Uri.parse('https://dummyjson.com/products/categories');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List && data.isNotEmpty && data.first is Map) {
          final List<String> names =
          data.map<String>((e) => e['name'].toString()).toList();
          final List<String> slug =
          data.map<String>((e) => e['slug'].toString()).toList();
          categories.assignAll(names);
          slugs.assignAll(slug);
          fullCategories.assignAll(names);
        } else {
          categories.assignAll(List<String>.from(data));
          fullCategories.assignAll(List<String>.from(data));
        }
        categories.insert(0, 'all');
        slugs.insert(0, 'all');
      }
    } catch (e) {
      log("❌ Exception: $e");
    } finally {
      isCategoryLoading.value = false;
    }
  }

  // 🔹 Products by Category
  Future<void> fetchProductsByCategory(String category) async {
    isProductLoading.value = true;
    noResultsFound.value = false;

    try {
      Uri url;
      if (category.toLowerCase() == 'all') {
        url = Uri.parse('https://dummyjson.com/products?limit=1000');
      } else {
        url = Uri.parse(
            'https://dummyjson.com/products/category/${Uri.encodeComponent(category)}?limit=1000');
      }

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        posts.assignAll(data["products"]);
        noResultsFound.value = posts.isEmpty;
      }
    } catch (e) {
      noResultsFound.value = true;
    } finally {
      isProductLoading.value = false;
    }
  }

  // 🔹 Search
  Future<void> searchProducts(String query) async {
    userInitiatedSearch.value = true;
    isInitialLoad.value = false;
    isProductLoading.value = true;
    noResultsFound.value = false;

    try {
      if (query.trim().isEmpty) {
        await fetchProductsByCategory('all');
        return;
      }

      final url = Uri.parse(
          'https://dummyjson.com/products/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        posts.assignAll(data["products"]);
        noResultsFound.value = posts.isEmpty;
      } else {
        noResultsFound.value = true;
      }
    } catch (e) {
      noResultsFound.value = true;
    } finally {
      isProductLoading.value = false;
    }
  }

  // 🔹 Fetch Cart
  Future<void> fetchCart(int userId) async {
    isCartLoading.value = true;
    final url = Uri.parse("https://dummyjson.com/carts/$userId");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        cart.assignAll(data);
        log("🛒 Cart Loaded: ${cart['products']?.length ?? 0} items");
      }
    } catch (e) {
      log("❌ Cart Exception: $e");
    } finally {
      isCartLoading.value = false;
    }
  }
  Future<bool> addToCart(int userId, int productId, int quantity) async {
    isCartLoading.value = true;
    try {
      final response = await http.post(
        Uri.parse("https://dummyjson.com/carts/add"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "userId": userId,
          "products": [
            {"id": productId, "quantity": quantity}
          ]
        }),
      );

      print(response.body);
      print(response.statusCode);
      print('response.statusCode');
      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        // ✅ get first product returned
        final productData = data['products'][0];

        // ✅ make sure cart has structure
        cart['products'] ??= [];
        cart['totalQuantity'] ??= 0;

        final List products = List.from(cart['products']);

        // ✅ check if product already in cart
        final existingIndex =
        products.indexWhere((item) => item['id'] == productData['id']);

        if (existingIndex >= 0) {
          products[existingIndex]['quantity'] += quantity;
        } else {
          products.add({
            "id": productData['id'],
            "title": productData['title'],
            "price": productData['price'],
            "quantity": productData['quantity'],
            "thumbnail": productData['thumbnail'],
          });
        }

        // ✅ update local cart map
        cart['products'] = products;
        cart['totalQuantity'] =
            (cart['totalQuantity'] as int) + quantity;

        // ✅ navigate to cart tab
        selectedIndex.value = 2;

        showSnackBar("${productData['title']} added to cart");

        return true;
      } else {
        debugPrint("❌ Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
      return false;
    } finally {
      isCartLoading.value = false;
    }
  }







}

class ProfileImagePreview extends StatelessWidget {
  final File? profileImage;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const ProfileImagePreview({
    super.key,
    required this.profileImage,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: onChange,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
      body: Center(
        child: profileImage != null
            ? Image.file(profileImage!, fit: BoxFit.contain)
            : Image.asset("assets/images/img_4.png", fit: BoxFit.contain),
      ),
    );
  }
}




class Newpage extends StatefulWidget {
  const Newpage({super.key});

  @override
  State<Newpage> createState() => _NewpageState();
}

class _NewpageState extends State<Newpage> {





  void _showEditProfileDialog(String currentName, String currentEmail) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail);

    Get.dialog(
      AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("username", nameCtrl.text);
              await prefs.setString("email", emailCtrl.text);
              Get.back();
              Get.snackbar("Profile Updated", "Your details have been saved",
                  snackPosition: SnackPosition.BOTTOM);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }



  int _calculateCartTotal() {
    if (controller.cart['products'] == null) return 0;

    return (controller.cart['products'] as List).fold(0, (sum, item) {
      final price = (item['price'] as num).toDouble();
      final qty = (item['quantity'] as num).toInt();
      return sum + (price * qty).round(); // ✅ safely convert double → int
    });
  }


  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _categoryScrollController = ScrollController();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }



  void openCheckout(int totalAmount) {
    var options = {
      'key': 'rzp_test_RAJV8WSouSWp6g',
      'amount': totalAmount * 100,
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




  final NavigationController controller = Get.put(NavigationController());

  final TextEditingController searchController = TextEditingController();
  late ScrollController _scrollController;
  late ScrollController _categoryScrollController;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      body: IndexedStack(
        index: controller.selectedIndex.value,
        children: [
          page1(),
          page2(),
          page3(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    ));
  }

  final List<Color> bubbleColors = [
    Colors.indigo,
    Colors.orange,
    Colors.red,
  ];

  Widget _buildBottomNav() {
    return Obx(() {
      if (controller.isInitialLoad.value) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 70,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        );
      } else {
        return Container(
          height: 85,
          margin: const EdgeInsets.symmetric(horizontal:10, vertical: 20),

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF42A5F5), // light blue
                Color(0xFFFFFFFF), // white bottom
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, "Home", 0),
                _buildNavItem(Icons.person, "Profile", 1),
                Obx(() {
                  final cartCount = controller.cart['totalQuantity'] ?? 0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildNavItem(Icons.shopping_cart, "Cart", 2),

                      // 🔥 Show badge only if cart has items
                      if (cartCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: badges.Badge(
                            badgeContent: Text(
                              cartCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            badgeStyle: const badges.BadgeStyle(
                              badgeColor: Colors.red,
                              padding: EdgeInsets.all(5),
                            ),
                          ),
                        ),
                    ],
                  );
                })

              ],
            ),
          ),
        );
      }
    });
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = controller.selectedIndex.value == index;

    return GestureDetector(
      onTap: () => controller.selectedIndex.value = index,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,

              margin: EdgeInsets.only(bottom: isSelected ? 10 : 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? bubbleColors[index] : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: bubbleColors[index].withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  )
                ]
                    : [],
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? bubbleColors[index] : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }





  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Flipkart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text(
                  'Select delivery location',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 10,),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(width: 2, color: Colors.blue),
                    ),
                    child: TextField(
                      controller: searchController,
                      onSubmitted: (value) => controller.searchProducts(value),
                      decoration: const InputDecoration(
                        hintText: "Search for products...",
                        prefixIcon: Icon(Icons.search, color: Colors.blue),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildCategoryList() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        key: const PageStorageKey('CATEGORY_LIST'),
        controller: _categoryScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: controller.categories.length,
        itemBuilder: (_, index) {
          final String category = controller.categories[index];
          final String slug = controller.slugs[index];
          final bool isSelected = controller.selectedCategory.value == category;

          return GestureDetector(
            onTap: () {
              controller.selectedCategory.value = category;
              controller.fetchProductsByCategory(slug);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.pink : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.category,
                    color: isSelected ? Colors.white : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.formatCategoryName(category),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildProductCard(dynamic post) {
    final String? imageUrl = (post['images'] != null && post['images'] is List && post['images'].isNotEmpty)
        ? post['images'][0] as String
        : null;

    final RxInt quantity = 1.obs;

    return GestureDetector(
      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Shoppage(productId: post['id']),
          ),
        );
      },

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child:
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: imageUrl != null
                    ? Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 130,
                  fit: BoxFit.cover,
                )
                    : Container(
                  height: 130,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                          5,
                              (index) => Icon(
                            index < 3 ? Icons.star : Icons.star_border,
                            color: index < 3 ? Colors.orange : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            "\$9999",
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "\$${post['price']}",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }


  Widget page1() {
    return Obx(() {
      final isInitial = controller.isInitialLoad.value;
      final isProductLoading = controller.isProductLoading.value;
      final noResults = controller.noResultsFound.value;

      return Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          _buildHeader(context),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(children: [Text("Popular Categories",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 28),)],),
                      ),
                      Obx(() {
                        if (controller.isCategoryLoading.value) {
                          return _buildHorizontalCategoryShimmer();
                        } else {
                          return _buildCategoryList();
                        }
                      }),
                    ],
                  ),
                ),
                if (isProductLoading)
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildShimmerItem(),
                      childCount: 10,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.65,
                    ),
                  )
                else if (noResults)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          "No products found",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final post = controller.posts[index];
                        return _buildProductCard(post);
                      },
                      childCount: controller.posts.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.60,
                    ),
                  ),
              ],
            ),

            if (isInitial)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: _buildShimmerGrid(),
                ),
              ),
          ],
        ),
      );
    });
  }


  File? _profileImage;

  Future<Map<String, String>> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "username": prefs.getString("username") ?? "Guest User",
      "email": prefs.getString("email") ?? "guest@email.com",
    };
  }

  Future<File?> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString("profileImage");
    if (path != null && path.isNotEmpty) return File(path);
    return null;
  }
  Future<void> _showProfileImageOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Take Photo"),
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString("profileImage", picked.path);
                    setState(() {
                      _profileImage = File(picked.path);
                    });
                  }
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.green),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString("profileImage", picked.path);
                    setState(() {
                      _profileImage = File(picked.path);
                    });
                  }
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Remove Photo"),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove("profileImage");
                  setState(() {
                    _profileImage = null;
                  });
                  Navigator.pop(ctx);
                },
              ),

            ],
          ),
        );
      },
    );
  }






  Future<void> _showAddressDialog() async {
    final addressController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("Add Address"),
        content: TextField(
          controller: addressController,
          decoration: const InputDecoration(hintText: "Enter your delivery address"),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("address", addressController.text);
              Get.back();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: "Old Password")),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "New Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("password", newPass.text);
              Get.back();
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }



  Widget page2() {
    return FutureBuilder<Map<String, String>>(
      future: _loadUserInfo(),
      builder: (context, snapshot) {
        final username = snapshot.data?['username'] ?? "Guest User";
        final email = snapshot.data?['email'] ?? "guest@email.com";

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 🔹 Profile Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      FutureBuilder<File?>(
                        future: _loadProfileImage(),
                        builder: (context, imgSnapshot) {
                          _profileImage = imgSnapshot.data;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileImagePreview(
                                    profileImage: _profileImage,
                                    onChange: () {
                                      Navigator.pop(context); // close preview
                                      _showProfileImageOptions(context); // open bottom sheet again
                                    },
                                    onRemove: () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.remove("profileImage");
                                      setState(() {
                                        _profileImage = null;
                                      });
                                      Navigator.pop(context); // close preview
                                    },
                                  ),
                                ),
                              );
                            },

                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : const AssetImage("assets/images/img_4.png") as ImageProvider,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(email, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Options
                _buildOptionCard(icon: Icons.person, title: "Edit Profile", subtitle: "Update your details", onTap: () => _showEditProfileDialog(username, email)),
                _buildOptionCard(icon: Icons.shopping_bag, title: "My Orders", subtitle: "Track, return or buy again", onTap: () { Get.snackbar("Orders", "No orders yet"); }),
                _buildOptionCard(icon: Icons.home, title: "My Addresses", subtitle: "Manage delivery locations", onTap: () => _showAddressDialog()),
                _buildOptionCard(icon: Icons.security, title: "Change Password", subtitle: "Update login password", onTap: () => _showChangePasswordDialog()),
                _buildOptionCard(icon: Icons.dark_mode, title: "Dark Mode", subtitle: "Switch theme", onTap: () { Get.changeTheme(Get.isDarkMode ? ThemeData.light() : ThemeData.dark()); }),
                _buildOptionCard(icon: Icons.help, title: "Help Center", subtitle: "FAQs & Support", onTap: () { Get.snackbar("Help", "Contact us at support@email.com"); }),

                const SizedBox(height: 30),

                // 🔹 Logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Logout"),
                          content: const Text("Are you sure you want to log out?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout")),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Get.offAll(Loginpage());
                      }
                    },
                    label: const Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }





  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }



  Widget page3() {
    return Obx(() {
      if (controller.isCartLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.cart['products'] == null ||
          (controller.cart['products'] as List).isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/img_3.png", width: 200, height: 200),
              const SizedBox(height: 20),
              const Text(
                "Your cart is empty",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  controller.selectedIndex.value = 0;
                },
                child: const Text(
                  "Continue Shopping",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // 🔹 Cart items scrollable section
          Expanded(
            child: ListView.builder(
              itemCount: controller.cart['products']?.length ?? 0,
              itemBuilder: (context, index) {
                final item = controller.cart['products'][index];
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading:
                    Image.network(item['thumbnail'], width: 50, height: 50),
                    title: Text(item['title']),
                    subtitle: Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_rounded),
                            onPressed: item['quantity'] > 1
                                ? () {
                              controller.updateCartQuantity(
                                item['id'],
                                item['quantity'] - 1,
                              );
                            }
                                : null,
                          ),
                          SizedBox(width: 10,),
                          Text(
                            "${item['quantity']}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          SizedBox(width: 10,),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () {
                              controller.updateCartQuantity(
                                item['id'],
                                item['quantity'] + 1,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child:
                          Text(
                            "₹${(item['price'] * item['quantity']).toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),

                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              controller.removeFromCart(item['id']);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                  Text("${item['title']} removed from cart"),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                            child: const Text("Remove"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 🔹 Fixed bottom payment section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total: ₹${_calculateCartTotal()}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final total = _calculateCartTotal();
                    if (total > 0) {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Confirm Payment",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Text("You are about to pay ₹$total"),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    openCheckout(total); // Razorpay payment
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text("Proceed to Pay"),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Your cart is empty")),
                      );
                    }
                  },
                  label: const Text(
                    "Proceed to Pay",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ],
      );
    });
  }

}








  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(4),
      ),
    );
  }




  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.62,
        ),
        itemCount: 6,
        itemBuilder: (_, __) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake image block
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                  ),
                ),
                // Fake text lines
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 120, color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 60, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildHorizontalCategoryShimmer() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        itemBuilder: (_, __) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Shimmer.fromColors(
              baseColor: Colors.red.shade200,
              highlightColor: Colors.red.shade50,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
