@EndUserText.label: 'Stock Movement'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define view entity ZSIM_I_STOCKMOVEMENT
  as select from zsim_stock_mvt
  association to parent ZSIM_I_STOCK as _Stock
    on  $projection.ProductId = _Stock.ProductId
    and $projection.PlantId   = _Stock.PlantId
  association [1..1] to ZSIM_I_PRODUCT as _Product
    on  $projection.ProductId = _Product.ProductId
{
  key movement_id   as MovementId,
      product_id    as ProductId,
      plant_id      as PlantId,
      movement_type as MovementType,
      quantity      as Quantity,
      stock_after   as StockAfter,
      reference     as Reference,
      created_by    as CreatedBy,
      created_at    as CreatedAt,

      /* Associations */
      _Stock,
      _Product
}
