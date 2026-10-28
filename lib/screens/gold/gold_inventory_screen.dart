// lib/screens/gold/gold_inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/gold_item.dart';
import '../../providers/gold_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/responsive_layout.dart';
import 'add_gold_screen.dart';

class GoldInventoryScreen extends StatefulWidget {
  final Function(int tab, {Map<String, dynamic>? initialParams})?
      onNavigate;

  const GoldInventoryScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<GoldInventoryScreen> createState() =>
      _GoldInventoryScreenState();
}

class _GoldInventoryScreenState
    extends State<GoldInventoryScreen> {
  final TextEditingController _searchCtrl =
      TextEditingController();

  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<GoldProvider>().fetchGoldItems();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // ADD GOLD ITEM
  // ============================================================

  Future<void> _openAddGoldModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      child: const AddGoldScreen(),
    );

    if (result == true && mounted) {
      context.read<GoldProvider>().fetchGoldItems(
            status: _selectedStatusFilter == 'ALL'
                ? null
                : _selectedStatusFilter,
            search: _searchCtrl.text.trim(),
          );
    }
  }

  // ============================================================
  // RESPONSIVE BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoldProvider>();
    final items = provider.goldItems;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final bool isDesktop = width >= 1100;
            final bool isTablet =
                width >= 700 && width < 1100;
            final bool isMobile = width < 700;

            // --------------------------------------------------
            // WEIGHT TOTALS
            // --------------------------------------------------

            double totalWeight = 0.0;
            double availableWeight = 0.0;
            double pledgedWeight = 0.0;
            double releasedWeight = 0.0;

            for (final item in items) {
              final weight = item.weight;

              totalWeight += weight;

              if (item.status == 'AVAILABLE') {
                availableWeight += weight;
              }

              if (item.status == 'PLEDGED') {
                pledgedWeight += weight;
              }

              if (item.status == 'RELEASED') {
                releasedWeight += weight;
              }
            }

            // --------------------------------------------------
            // RESPONSIVE PAGE PADDING
            // --------------------------------------------------

            final double pagePadding = isMobile
                ? 10
                : isTablet
                    ? 14
                    : 20;

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // =================================================
                  // STATISTICS
                  // =================================================

                  _buildStatisticsSection(
                    totalWeight: totalWeight,
                    availableWeight: availableWeight,
                    pledgedWeight: pledgedWeight,
                    releasedWeight: releasedWeight,
                    isMobile: isMobile,
                    isTablet: isTablet,
                  ),

                  SizedBox(
                    height: isMobile ? 10 : 16,
                  ),

                  // =================================================
                  // SEARCH / FILTER / ADD
                  // =================================================

                  _buildSearchSection(
                    provider: provider,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),

                  SizedBox(
                    height: isMobile ? 10 : 16,
                  ),

                  // =================================================
                  // CONTENT
                  // =================================================

                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child:
                                CircularProgressIndicator(
                              color:
                                  AppTheme.goldPrimary,
                            ),
                          )
                        : items.isEmpty
                            ? _buildEmptyState()
                            : isDesktop
                                ? _buildDesktopTable(items)
                                : _buildResponsiveCards(
                                    items,
                                    isTablet: isTablet,
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // STATISTICS SECTION
  // ============================================================

  Widget _buildStatisticsSection({
    required double totalWeight,
    required double availableWeight,
    required double pledgedWeight,
    required double releasedWeight,
    required bool isMobile,
    required bool isTablet,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth;

          final double itemWidth;

          if (isMobile) {
            itemWidth =
                (availableWidth - 10) / 2;
          } else if (isTablet) {
            itemWidth =
                (availableWidth - 16) / 2;
          } else {
            itemWidth = 180;
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: itemWidth,
                child: _statItem(
                  'Total Gold Weight',
                  AppConstants.formatWeight(
                    totalWeight,
                  ),
                  Icons.scale,
                  isGold: true,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _statItem(
                  'Available Gold',
                  AppConstants.formatWeight(
                    availableWeight,
                  ),
                  Icons.check_circle_outline,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _statItem(
                  'Pledged Collateral',
                  AppConstants.formatWeight(
                    pledgedWeight,
                  ),
                  Icons.lock_outline,
                  isGold: true,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _statItem(
                  'Released Gold',
                  AppConstants.formatWeight(
                    releasedWeight,
                  ),
                  Icons.lock_open,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // STAT ITEM
  // ============================================================

  Widget _statItem(
    String label,
    String value,
    IconData icon, {
    bool isGold = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isGold
            ? AppTheme.goldLight.withValues(alpha: 0.4)
            : AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGold
              ? AppTheme.goldPrimary
              : AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isGold
                ? AppTheme.goldDark
                : AppTheme.darkNavy,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.silverDark,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                    color: isGold
                        ? AppTheme.goldDark
                        : AppTheme.darkNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH / FILTER / ADD
  // ============================================================

  Widget _buildSearchSection({
    required GoldProvider provider,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isMobile) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(provider),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildFilterDropdown(
                        provider,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildAddButton(
                        isMobile: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          if (isTablet) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(provider),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    _buildFilterDropdown(
                      provider,
                    ),
                    const SizedBox(width: 12),
                    _buildAddButton(
                      isMobile: false,
                    ),
                  ],
                ),
              ],
            );
          }

          // ------------------------------------------------------
          // DESKTOP
          // ------------------------------------------------------

          return Row(
            children: [
              Expanded(
                child:
                    _buildSearchField(provider),
              ),
              const SizedBox(width: 12),
              _buildFilterDropdown(provider),
              const SizedBox(width: 12),
              _buildAddButton(
                isMobile: false,
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // SEARCH FIELD
  // ============================================================

  Widget _buildSearchField(
    GoldProvider provider,
  ) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText:
            'Search gold item, customer name, code...',
        prefixIcon: const Icon(
          Icons.search,
          color: AppTheme.silverDark,
        ),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();

                  provider.fetchGoldItems(
                    status:
                        _selectedStatusFilter ==
                                'ALL'
                            ? null
                            : _selectedStatusFilter,
                    search: '',
                  );

                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (value) {
        provider.fetchGoldItems(
          status:
              _selectedStatusFilter == 'ALL'
                  ? null
                  : _selectedStatusFilter,
          search: value.trim(),
        );

        setState(() {});
      },
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget _buildFilterDropdown(
    GoldProvider provider,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatusFilter,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
          ),
          items: const [
            DropdownMenuItem(
              value: 'ALL',
              child: Text('ALL'),
            ),
            DropdownMenuItem(
              value: 'AVAILABLE',
              child: Text('AVAILABLE'),
            ),
            DropdownMenuItem(
              value: 'PLEDGED',
              child: Text('PLEDGED'),
            ),
            DropdownMenuItem(
              value: 'RELEASED',
              child: Text('RELEASED'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedStatusFilter =
                  value;
            });

            provider.fetchGoldItems(
              status: value == 'ALL'
                  ? null
                  : value,
              search:
                  _searchCtrl.text.trim(),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ADD BUTTON
  // ============================================================

  Widget _buildAddButton({
    required bool isMobile,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _openAddGoldModal,
        icon: const Icon(
          Icons.add,
          size: 18,
        ),
        label: Text(
          isMobile
              ? 'Add'
              : 'Add Gold Item',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              AppTheme.goldPrimary,
          foregroundColor:
              AppTheme.darkNavy,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP TABLE
  // ============================================================

  Widget _buildDesktopTable(
    List<GoldItem> items,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            // ==================================================
            // VERTICAL + HORIZONTAL SCROLL
            // ==================================================

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                primary: true,
                physics:
                    const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(
                      minWidth:
                          constraints.maxWidth,
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.45),
                        1: FlexColumnWidth(0.65),
                        2: FlexColumnWidth(1.05),
                        3: FlexColumnWidth(1.50),
                        4: FlexColumnWidth(0.90),
                        5: FlexColumnWidth(0.95),
                        6: FlexColumnWidth(1.10),
                      },
                      border: const TableBorder(
                        horizontalInside:
                            BorderSide(
                          color:
                              AppTheme.silverBorder,
                          width: 0.8,
                        ),
                      ),
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment
                              .middle,
                      children: [
                        // ==================================================
                        // HEADER
                        // ==================================================

                        TableRow(
                          decoration:
                              const BoxDecoration(
                            color:
                                AppTheme.silverLight,
                          ),
                          children: [
                            _tableHeader(
                                'Item Name'),
                            _tableHeader(
                                'Purity'),
                            _tableHeader(
                                'Gross Weight'),
                            _tableHeader(
                                'Customer'),
                            _tableHeader(
                                'Locker No'),
                            _tableHeader(
                                'Status'),
                            _tableHeader(
                                'Remarks'),
                          ],
                        ),

                        // ==================================================
                        // DATA ROWS
                        // ==================================================

                        ...items.map(
                          (g) => TableRow(
                            children: [
                              _buildItemNameCell(
                                g,
                                compact: false,
                              ),

                              _tableCell(
                                Text(
                                  g.purity,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              ),

                              _tableCell(
                                Text(
                                  AppConstants
                                      .formatWeight(
                                    g.weight,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              _tableCell(
                                Text(
                                  '${g.customerName ?? '-'}'
                                  ' (${g.customerCode ?? ''})',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              ),

                              _tableCell(
                                Text(
                                  g.loanNo ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: g.loanNo != null ? AppTheme.goldDark : AppTheme.darkNavy,
                                  ),
                                ),
                              ),

                              _tableCell(
                                FittedBox(
                                  fit: BoxFit
                                      .scaleDown,
                                  alignment:
                                      Alignment
                                          .centerLeft,
                                  child: GoldBadge(
                                    status:
                                        g.status,
                                  ),
                                ),
                              ),

                              _tableCell(
                                Text(
                                  g.remarks ?? '-',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color:
                                        AppTheme
                                            .silverDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _tableHeader(String text) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 62,
      ),
      alignment: Alignment.centerLeft,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow:
            TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppTheme.darkNavy,
        ),
      ),
    );
  }

  // ============================================================
  // TABLE CELL
  // ============================================================

  Widget _tableCell(
    Widget child, {
    Alignment alignment =
        Alignment.centerLeft,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 62,
      ),
      alignment: alignment,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: child,
    );
  }

  // ============================================================
  // ITEM NAME CELL
  // ============================================================

  Widget _buildItemNameCell(
    GoldItem g, {
    required bool compact,
  }) {
    final resolvedUrl = ApiService.resolvePhotoUrl(g.photoUrl);
    final double avatarRadius = compact ? 18 : 16;

    return _tableCell(
      Row(
        children: [
          if (resolvedUrl != null && resolvedUrl.isNotEmpty)
            Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: const BoxDecoration(
                color: AppTheme.goldLight,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.network(
                  resolvedUrl,
                  width: avatarRadius * 2,
                  height: avatarRadius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.diamond,
                        size: compact ? 18 : 15,
                        color: AppTheme.goldDark,
                      ),
                    );
                  },
                ),
              ),
            )
          else
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppTheme.goldLight,
              child: Icon(
                Icons.diamond,
                size: compact ? 18 : 15,
                color: AppTheme.goldDark,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              g.itemName,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 13,
                color:
                    AppTheme.darkNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLET + MOBILE CARDS
  // ============================================================

  Widget _buildResponsiveCards(
    List<GoldItem> items, {
    required bool isTablet,
  }) {
    if (isTablet) {
      return Scrollbar(
        thumbVisibility: true,
        child: GridView.builder(
          primary: true,
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.only(
            bottom: 8,
          ),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.25,
          ),
          itemCount: items.length,
          itemBuilder:
              (context, index) {
            return _buildGoldCard(
              items[index],
              compact: true,
            );
          },
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        primary: true,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(
          bottom: 8,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
        itemBuilder:
            (context, index) {
          return _buildGoldCard(
            items[index],
            compact: false,
          );
        },
      ),
    );
  }

  // ============================================================
  // GOLD CARD
  // ============================================================

  Widget _buildGoldCard(
    GoldItem g, {
    required bool compact,
  }) {
    final bool hasPhoto =
        g.photoUrl != null &&
        g.photoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: 
              0.03,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? 12 : 14,
        ),
        child: compact
            ? _buildTabletCardContent(
                g,
                hasPhoto,
              )
            : _buildMobileCardContent(
                g,
                hasPhoto,
              ),
      ),
    );
  }

  // ============================================================
  // TABLET CARD
  // ============================================================

  Widget _buildTabletCardContent(
    GoldItem g,
    bool hasPhoto,
  ) {
    return Row(
      children: [
        _buildGoldImage(
          g,
          hasPhoto,
          radius: 22,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                g.itemName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                  color:
                      AppTheme.darkNavy,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                '${g.purity} • '
                '${AppConstants.formatWeight(g.weight)}',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                g.customerName ?? '-',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      AppTheme.silverDark,
                ),
              ),

              if (g.loanNo != null &&
                  g.loanNo!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Loan: ${g.loanNo}',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: GoldBadge(
            status: g.status,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE CARD
  // ============================================================

  Widget _buildMobileCardContent(
    GoldItem g,
    bool hasPhoto,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildGoldImage(
              g,
              hasPhoto,
              radius: 22,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                g.itemName,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                  color:
                      AppTheme.darkNavy,
                ),
              ),
            ),

            const SizedBox(width: 8),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: GoldBadge(
                status: g.status,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _mobileInfoRow(
          'Purity',
          g.purity,
        ),

        _mobileInfoRow(
          'Weight',
          AppConstants.formatWeight(
            g.weight,
          ),
        ),

        _mobileInfoRow(
          'Customer',
          '${g.customerName ?? '-'}'
          ' (${g.customerCode ?? ''})',
        ),

        _mobileInfoRow(
          'Loan No',
          g.loanNo ?? '-',
        ),

        _mobileInfoRow(
          'Remarks',
          g.remarks ?? '-',
        ),
      ],
    );
  }

  // ============================================================
  // GOLD IMAGE
  // ============================================================

  Widget _buildGoldImage(
    GoldItem g,
    bool hasPhoto, {
    required double radius,
  }) {
    final resolvedUrl = ApiService.resolvePhotoUrl(g.photoUrl);

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: AppTheme.goldLight,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            resolvedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.diamond,
                  size: radius,
                  color: AppTheme.goldDark,
                ),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.goldLight,
      child: Icon(
        Icons.diamond,
        size: radius,
        color: AppTheme.goldDark,
      ),
    );
  }

  // ============================================================
  // MOBILE INFO ROW
  // ============================================================

  Widget _mobileInfoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 11,
                color:
                    AppTheme.silverDark,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const Text(
            ': ',
            style: TextStyle(
              fontSize: 11,
              color:
                  AppTheme.silverDark,
            ),
          ),

          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 11,
                color:
                    AppTheme.darkNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color:
                  AppTheme.silverDark,
            ),
            SizedBox(height: 12),
            Text(
              'No gold items found',
              style: TextStyle(
                color:
                    AppTheme.silverDark,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}