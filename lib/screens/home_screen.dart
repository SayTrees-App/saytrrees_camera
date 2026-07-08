import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    // Filter items based on selected category
    var filteredItems = appState.selectedCategory == 'ALL'
        ? appState.capturedImages
        : appState.capturedImages.where((item) => item.category == appState.selectedCategory).toList();

    // Sort items based on date toggle (they are naturally descending in AppState)
    filteredItems = filteredItems.reversed.toList();

    final _isDarkMode = appState.isDarkMode;
    final bgColor = _isDarkMode ? const Color(0xFF041710) : const Color(0xFFF8F9FA);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(appState, bgColor),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(appState),
            _buildFilters(appState),
            Expanded(
              child: appState.currentView == 'Grid' ? _buildGrid(filteredItems, appState) : _buildGalleryGrid(filteredItems, appState),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppStateProvider appState, Color bgColor) {
    final _isDarkMode = appState.isDarkMode;
    final textColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF012D1D);
    final subTextColor = _isDarkMode ? const Color(0xFFD1E8DC) : const Color(0xFF414844);
    final surfaceColor = _isDarkMode ? const Color(0xFF10231C) : const Color(0xFFE1E3E4);

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: surfaceColor,
                  child: Icon(Icons.person, color: textColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SayTrees',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: textColor,
                        ),
                      ),
                      Text(
                        appState.currentLocation,
                        style: TextStyle(
                          fontSize: 10,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode, 
              color: textColor
            ),
            onPressed: () {
              appState.toggleTheme();
            },
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppStateProvider appState) {
    final _isDarkMode = appState.isDarkMode;
    final surfaceColor = _isDarkMode ? const Color(0xFF10231C) : const Color(0xFFF8F9FA);
    final borderColor = _isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFC1C8C2);
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final hintColor = _isDarkMode ? const Color(0xFF8A938C) : const Color(0xFF717973);
    final accentColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF012D1D);
    final activeBgColor = _isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFE1E3E4);
    final activeTextColor = _isDarkMode ? Colors.white : const Color(0xFF012D1D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search gallery...',
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.search, color: accentColor), 
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => appState.setCurrentView(appState.currentView == 'Grid' ? 'List' : 'Grid'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: activeBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(appState.currentView == 'Grid' ? Icons.view_list : Icons.grid_view, size: 16, color: activeTextColor),
                        const SizedBox(width: 4),
                        Text(appState.currentView == 'Grid' ? 'List' : 'Grid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: activeTextColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AppStateProvider appState) {
    final _isDarkMode = appState.isDarkMode;
    final activeBgColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF012D1D);
    final activeTextColor = _isDarkMode ? const Color(0xFF041710) : Colors.white;
    final inactiveBgColor = _isDarkMode ? const Color(0xFF10231C) : const Color(0xFFF8F9FA);
    final inactiveTextColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF414844);
    final borderColor = _isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFC1C8C2);

    final categories = [
      'ALL',
      'Agroforestry',
      'Forestry',
      'Biogas',
      'Water Conservation',
      'Biochar',
      'Mangroves',
      'Bamboo',
    ];
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = appState.selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(
                category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: isSelected ? activeTextColor : inactiveTextColor,
                ),
              ),
              backgroundColor: isSelected ? activeBgColor : inactiveBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : borderColor,
                ),
              ),
              onPressed: () {
                appState.setCategory(category);
              },
            ),
          );
        },
      ),
    );
  }

  Map<String, List<CapturedImage>> _groupByDate(List<CapturedImage> items) {
    final Map<String, List<CapturedImage>> grouped = {};
    for (var item in items) {
      final date = item.dateTime.split(',').first.trim();
      grouped.putIfAbsent(date, () => []).add(item);
    }
    return grouped;
  }

  // --- COMPACT GRID VIEW ---
  Widget _buildGrid(List<CapturedImage> items, AppStateProvider appState) {
    if (items.isEmpty) return _buildEmptyState(appState);

    final _isDarkMode = appState.isDarkMode;
    final cardBgColor = _isDarkMode ? const Color(0xFF10231C) : Colors.white;
    final borderColor = _isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFE1E3E4);
    final overlayColor = _isDarkMode ? const Color(0xFF95D4B3) : Colors.white;

    final grouped = _groupByDate(items);

    return CustomScrollView(
      slivers: grouped.entries.expand((entry) {
        final dateStr = entry.key;
        final dateItems = entry.value;
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Text(
                dateStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? const Color(0xFFD1E8DC) : const Color(0xFF2C694E),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = dateItems[index];
                  final hasValidImage = item.path.isNotEmpty && File(item.path).existsSync();

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: cardBgColor,
                      border: Border.all(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasValidImage && !item.isVideo)
                          Image.file(File(item.path), fit: BoxFit.cover)
                        else if (item.isVideo && item.thumbnailPath != null && File(item.thumbnailPath!).existsSync())
                          Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                        else
                          Icon(Icons.image_not_supported, color: _isDarkMode ? const Color(0xFF8A938C) : const Color(0xFFC1C8C2)),
                        if (item.isVideo)
                          const Center(
                            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.category.toUpperCase(),
                                  style: TextStyle(fontSize: 8, color: overlayColor, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.lat != null && item.lng != null)
                                  Text(
                                    '${item.lat!.toStringAsFixed(4)}, ${item.lng!.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 7, color: Colors.white70),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
                childCount: dateItems.length,
              ),
            ),
          ),
        ];
      }).toList(),
    );
  }

  Widget _buildEmptyState(AppStateProvider appState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: appState.isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFC1C8C2)),
          const SizedBox(height: 12),
          Text(
            'No images in this category yet.',
            style: TextStyle(color: const Color(0xFF8A938C), fontSize: 15),
          ),
        ],
      ),
    );
  }

  // --- RICH LIST VIEW ---
  Widget _buildGalleryGrid(List<CapturedImage> items, AppStateProvider appState) {
    if (items.isEmpty) return _buildEmptyState(appState);

    final grouped = _groupByDate(items);
    final _isDarkMode = appState.isDarkMode;

    List<Widget> children = [];
    for (var entry in grouped.entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? const Color(0xFFD1E8DC) : const Color(0xFF2C694E),
            ),
          ),
        ),
      );
      for (var item in entry.value) {
        children.add(_buildImageCard(item, appState));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }

  Widget _buildImageCard(CapturedImage item, AppStateProvider appState) {
    final hasValidImage = item.path.isNotEmpty && File(item.path).existsSync();
    
    final _isDarkMode = appState.isDarkMode;
    final cardBgColor = _isDarkMode ? const Color(0xFF10231C) : Colors.white;
    final borderColor = _isDarkMode ? const Color(0xFF2D6A4F) : const Color(0xFFE1E3E4);
    final shadowColor = _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.07);
    final emptyImgBg = _isDarkMode ? const Color(0xFF041710) : const Color(0xFFE1E3E4);
    final badgeBgColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF012D1D);
    final badgeTextColor = _isDarkMode ? const Color(0xFF041710) : Colors.white;
    final hintColor = _isDarkMode ? const Color(0xFF8A938C) : const Color(0xFF717973);
    final mainTextColor = _isDarkMode ? const Color(0xFFD1E8DC) : const Color(0xFF414844);
    final accentColor = _isDarkMode ? const Color(0xFF95D4B3) : const Color(0xFF2C694E);
    final noteBgColor = _isDarkMode ? const Color(0xFF041710) : const Color(0xFFF3F4F5);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasValidImage && !item.isVideo
                      ? Image.file(File(item.path), fit: BoxFit.cover)
                      : (item.isVideo && item.thumbnailPath != null && File(item.thumbnailPath!).existsSync())
                          ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                          : Container(
                          color: emptyImgBg,
                          child: Icon(Icons.image_not_supported,
                              size: 48, color: hintColor),
                        ),
                  if (item.isVideo)
                    const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                    ),
                ],
              ),
            ),
          ),

          // ── Metadata ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge + date row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 12, color: hintColor),
                    const SizedBox(width: 4),
                    Text(
                      item.dateTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Location
                _metaRow(
                  Icons.location_on,
                  item.location,
                  accentColor,
                  mainTextColor,
                ),

                // Altitude (if available)
                if (item.altitude != null) ...[
                  const SizedBox(height: 6),
                  _metaRow(
                    Icons.terrain,
                    'Altitude: ${item.altitude!.toStringAsFixed(1)} m',
                    hintColor,
                    mainTextColor,
                  ),
                ],

                // Lat / Lng (if available)
                if (item.lat != null && item.lng != null) ...[
                  const SizedBox(height: 6),
                  _metaRow(
                    Icons.my_location,
                    '${item.lat!.toStringAsFixed(5)}°, ${item.lng!.toStringAsFixed(5)}°',
                    hintColor,
                    mainTextColor,
                  ),
                ],

                // Notes (if any)
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: noteBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, size: 14, color: accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: mainTextColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color iconColor, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
