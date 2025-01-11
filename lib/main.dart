import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'services/unsplash_service.dart';
import 'config.dart' as app_config;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/loading_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:typed_data';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _currentThemeMode = ThemeMode.system; 
  Locale _currentLocale = const Locale('en', '');

  void _toggleTheme() {
    setState(() {
      _currentThemeMode = _currentThemeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
      _saveThemePreference(_currentThemeMode);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    setState(() => _currentThemeMode = ThemeMode.values.byName(themeModeString));
  }

  Future<void> _saveThemePreference(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.name);
  }

  void _changeLocale(Locale locale) {
    setState(() {
      _currentLocale = locale;
    });
  }

  Locale get currentLocale => _currentLocale;

  void set currentLocale(Locale locale) => _changeLocale(locale);
  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '壁纸工具',
      theme: app_config.Config.lightTheme,
      darkTheme: app_config.Config.darkTheme,
      themeMode: _currentThemeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), 
        Locale('zh', ''), 
      ],
      locale: _currentLocale,
      home: const WelcomeScreen(),
        routes: {
        '/home': (context) => const HomeScreen(),
        '/detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ImageDetailScreen(
            imageUrl: args['imageUrl'],
            imageId: args['imageId'],
            toggleTheme: _toggleTheme, // 将切换主题的方法传递给 ImageDetailScreen
            changeLocale: _changeLocale,
          );
        },
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
    _unsplashService = UnsplashService(app_config.Config.unsplashAccessKey);
    _loadImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: _selectedCategory,
        children: _categories.asMap().entries.map((entry) {
          return MapEntry(
            entry.value,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(entry.value),
            ),
          );
        }).toMap(),
        onValueChanged: (value) {
          if (value != null) {
            _changeCategory(value);
          }
        },
        thumbColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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
      controller: _scrollController, 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 两列
        crossAxisSpacing: 8.0, // 水平间距
        mainAxisSpacing: 8.0, // 垂直间距
        childAspectRatio: 1.0, // 宽高比
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          key: ValueKey(_imageUrls[index]), 
          onTap: () {
            Navigator.pushNamed(
              context,
              '/detail',
              arguments: <String, dynamic>{
                'imageUrl': _imageUrls[index],
                'imageId': _imageUrls[index].split('/').last,
              },
            );
          },
          child: InkWell( // 使用 InkWell 添加点击效果
            onTap: () {
              // ... existing navigation logic ...
            },
            borderRadius: BorderRadius.circular(8), // 设置圆角
            splashColor: Colors.grey.withOpacity(0.3), // 设置水波纹颜色
            highlightColor: Colors.grey.withOpacity(0.1), // 设置高亮颜色
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Hero(
                tag: _imageUrls[index],
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ImageDetailScreen extends StatefulWidget {
  final String imageUrl;
  final String imageId;
  final VoidCallback toggleTheme; // 添加切换主题的方法
  final ValueChanged<Locale> changeLocale; // 添加切换语言的方法

  const ImageDetailScreen({
    super.key,
    required this.imageUrl,
    required this.imageId,
    required this.toggleTheme, // 接收切换主题的方法
    required this.changeLocale, // 接收切换语言的方法
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  String get thumbnailUrl => '${widget.imageUrl}&w=400&h=400&fit=crop';
  bool _isDownloading = false;


 @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (context) {
                return _buildImageDetailsBottomSheet(context);
              },
            );
          },
          child: Hero(
            tag: widget.imageUrl,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
        )
    );
  }

  Widget _buildImageDetailsBottomSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('图片详情 #${widget.imageId}'),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
              width: 200,
              height: 200,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () async {
                  // ... existing share logic ...
                },
              ),
              if (!_isDownloading)
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    // ... existing download logic ...
                  },
                ),
            ],
          ),
        ],
      ),
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
    _unsplashService = UnsplashService(app_config.Config.unsplashAccessKey);
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
            child: _imageUrl != null
                ?
                // 使用 CachedNetworkImage 加载网络图片
                  CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Image.network(
                        'https://picsum.photos/800/600',
                        fit: BoxFit.cover, // 设置图片填充方式为 BoxFit.cover
                      ), // 加载网络图片出错时显示默认图片
                    )
                :
                // 加载网络图片前显示默认图片
                Image.network('https://picsum.photos/800/600', fit: BoxFit.cover),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          title: const Center(child: Text('欢迎')),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.5), // 透明度
          elevation: 0, // 去除阴影
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios), // 使用 iOS 风格的返回按钮
            onPressed: () {
              // 处理返回按钮的逻辑，例如 Navigator.pop(context)
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.light ? Icons.dark_mode : Icons.light_mode,
              ),
              onPressed: widget.toggleTheme, // 调用切换主题的方法
            ),
            DropdownButton<Locale>(
              value: (context.findAncestorStateOfType<_MyAppState>() as _MyAppState).currentLocale,
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  (context.findAncestorStateOfType<_MyAppState>() as _MyAppState).currentLocale = newLocale;
                }
              },
              items: const [
                DropdownMenuItem<Locale>(
                  value: Locale('en', ''),
                  child: Text('English'),
                ),
                DropdownMenuItem<Locale>(
                  value: Locale('zh', ''),
                  child: Text('中文'),
                ),
              ],
              icon: const Icon(Icons.language),
              underline: Container(
                height: 2,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
