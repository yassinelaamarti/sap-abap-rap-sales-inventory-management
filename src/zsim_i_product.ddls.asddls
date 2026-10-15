@EndUserText.label: 'Product'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZSIM_I_PRODUCT
  as select from zsim_product
  composition [0..*] of ZSIM_I_STOCK as _Stock
{
  key product_id        as ProductId,
      product_name      as ProductName,

      @Semantics.amount.currencyCode: 'Currency'
      unit_price        as UnitPrice,

      currency          as Currency,
      reorder_threshold as ReorderThreshold,

      /* Associations */
      _Stock
}
