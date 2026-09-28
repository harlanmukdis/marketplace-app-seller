import 'package:flutter/material.dart';

import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// One row of the catalogue (S-26).
///
/// There is no image and no stock count: `GET /stores/{id}/products` carries
/// neither, and a per-row detail call would be an N+1 for decoration. The
/// stock chip therefore shows the configured mode; the live split into Low
/// Stock / Stok Kosong appears on the product's own screen.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onToggleStatus,
  });

  final Product product;
  final VoidCallback? onTap;

  /// Publish / unpublish. Absent for a product whose status is neither draft
  /// nor active — archived rows are not toggled from a list.
  final VoidCallback? onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final compareAt = product.compareAtPrice;
    return XCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: XColors.sunken,
                  borderRadius: BorderRadius.circular(XRadius.md),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: XColors.textTertiary),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: XText.titleM,
                    ),
                    const SizedBox(height: XSpace.s4),
                    Row(
                      children: <Widget>[
                        Text(formatRupiah(product.effectivePrice),
                            style: XText.priceM),
                        if (compareAt != null &&
                            compareAt > product.effectivePrice) ...<Widget>[
                          const SizedBox(width: XSpace.s6),
                          Text(
                            formatRupiah(compareAt),
                            style: XText.caption.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ProductStatusPill(status: product.status),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          Wrap(
            spacing: XSpace.s6,
            runSpacing: XSpace.s6,
            children: <Widget>[
              StockModeChip(
                mode: product.stockMode,
                leadTimeDays: product.fulfillmentLeadTimeDays,
              ),
              if (product.isGrowthActive)
                XChip(
                  label: 'Growth '
                      '${product.growthCommissionPercent.toStringAsFixed(0)}%',
                  tone: XTone.info,
                  icon: Icons.trending_up_rounded,
                ),
              if (product.flashSale != null)
                const XChip(
                  label: 'Flash Sale',
                  tone: XTone.danger,
                  icon: Icons.bolt_rounded,
                ),
              if (product.soldCount > 0)
                XChip(label: '${product.soldCount} terjual'),
            ],
          ),
          if (onToggleStatus != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: XSpace.s12),
              child: Divider(height: 1, color: XColors.borderSubtle),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    product.isActive
                        ? 'Tayang di Xpedia'
                        : 'Belum terlihat pembeli',
                    style: XText.bodyS,
                  ),
                ),
                XButton.secondary(
                  label: product.isActive ? 'Nonaktifkan' : 'Tayangkan',
                  size: XButtonSize.small,
                  onPressed: onToggleStatus,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Product status, coloured from the design system.
class ProductStatusPill extends StatelessWidget {
  const ProductStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => XChip(
        label: ProductStatus.label(status),
        tone: switch (status) {
          ProductStatus.active => XTone.success,
          ProductStatus.draft => XTone.warning,
          _ => XTone.neutral,
        },
      );
}

/// The seven stock chips of design rule 9, each distinct.
class StockModeChip extends StatelessWidget {
  const StockModeChip({super.key, required this.mode, this.leadTimeDays});

  final String mode;
  final int? leadTimeDays;

  static XTone toneOf(String mode) => switch (mode) {
        FulfillmentMode.readyStock => XTone.success,
        FulfillmentMode.infinite => XTone.info,
        FulfillmentMode.preOrder => XTone.preOrder,
        FulfillmentMode.customOrder => XTone.customOrder,
        StockMode.lowStock => XTone.warning,
        StockMode.outOfStock => XTone.danger,
        _ => XTone.neutral,
      };

  static IconData iconOf(String mode) => switch (mode) {
        FulfillmentMode.readyStock => Icons.inventory_outlined,
        FulfillmentMode.infinite => Icons.all_inclusive_rounded,
        FulfillmentMode.preOrder => Icons.schedule_rounded,
        FulfillmentMode.customOrder => Icons.handyman_outlined,
        StockMode.lowStock => Icons.warning_amber_rounded,
        StockMode.outOfStock => Icons.remove_shopping_cart_outlined,
        _ => Icons.block_rounded,
      };

  @override
  Widget build(BuildContext context) => XChip(
        label: StockMode.label(mode, leadTimeDays: leadTimeDays),
        tone: toneOf(mode),
        icon: iconOf(mode),
      );
}
