@EndUserText.label: 'Sales Order Item'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define view entity ZSIM_I_SALESORDERITEM
  as select from zsim_so_item
  association to parent ZSIM_I_SALESORDER as _SalesOrder on $projection.OrderId    = _SalesOrder.OrderId
  association [0..1]    to ZSIM_I_PRODUCT as _Product    on $projection.ProductId  = _Product.ProductId
{
  key order_id       as OrderId,
  key item_number    as ItemNumber,
      product_id     as ProductId,
      plant_id       as PlantId,
      quantity       as Quantity,

      @Semantics.amount.currencyCode: 'Currency'
      net_amount     as NetAmount,
      currency       as Currency,

      /* Associations */
      _SalesOrder,
      _Product
}
