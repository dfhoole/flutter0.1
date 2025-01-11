import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/unsplash_service.dart';
import 'config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '欢迎界面',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final UnsplashService _unsplashService;
  List<String> _imageUrls = [];
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  final List<String> _categories = ['全部', '自然', '建筑', '食物', '人物'];
  String _selectedCategory = '全部';

  @override
  void initState() {
    super.initState();
    _unsplashService = UnsplashService(Config.unsplashAccessKey);
    _loadImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreImages();
    }
  }

  /// 加载图片列表
  /// 
  /// 参数：
  /// 无
  /// 
  /// 返回：
  /// Future<void> - 异步操作
  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentPage = 1;
    });

    try {
      final imageUrls = await _unsplashService.getImageList(
        perPage: 30,
        category: _selectedCategory == '全部' ? null : _selectedCategory,
      );
      setState(() {
        _imageUrls = imageUrls;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print('加载${_selectedCategory}图片失败：$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载${_selectedCategory}图片失败：$e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载更多图片
  /// 
  /// 参数：
  /// 无
  /// 
  /// 返回：
  /// Future<void> - 异步操作
  Future<void> _loadMoreImages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrls = await _unsplashService.getImageList(
        perPage: 30,
        page: _currentPage + 1,
        category: _selectedCategory == '全部' ? null : _selectedCategory,
      );
      setState(() {
        _imageUrls.addAll(imageUrls);
        _currentPage++;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载更多${_selectedCategory}图片失败：$e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('壁纸工具'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(child: _buildImageGrid()),
        ],
      ),
    );
  }

  /// 构建分类按钮栏
  /// 
  /// 参数：
  /// 无
  /// 
  /// 返回：
  /// Widget - 分类按钮栏组件
  Widget _buildCategoryBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                if (selected) {
                  _changeCategory(category);
                }
              },
            ),
          );
        },
      ),
    );
  }

  /// 构建图片网格布局
  /// 
  /// 参数：
  /// 无
  /// 
  /// 返回：
  /// Widget - 图片网格组件
  Widget _buildImageGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败，请重试'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadImages,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: _imageUrls[index],
            fit: BoxFit.cover,
            maxWidthDiskCache: 1000,
            maxHeightDiskCache: 1000,
            cacheKey: _imageUrls[index],
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final UnsplashService _unsplashService;
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _unsplashService = UnsplashService(Config.unsplashAccessKey);
    _loadRandomImage();
  }

  Future<void> _loadRandomImage() async {
    setState(() {
      _isLoading = true;
      _imageUrl = null;
    });

    try {
      final imageUrl = await _unsplashService.getRandomImageUrl();
      setState(() {
        _imageUrl = imageUrl;
      });
    } catch (e) {
      setState(() {
        _imageUrl = 'https://picsum.photos/800/600';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载随机图片失败，已显示默认图片')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _imageUrl != null ? 
                  CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Image.network(
                        'https://picsum.photos/800/600',
                        fit: BoxFit.cover,
                      ),
                    ) 
                : Image.network(
                    'https://picsum.photos/800/600',
                    fit: BoxFit.cover,
                  ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '欢迎使用本应用',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadRandomImage,
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/home');
                  },
                  child: const Text('开始使用'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
