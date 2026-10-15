@EndUserText.label: 'Products with stock per plant (value help)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true

define view entity ZSIM_I_PRODUCTPLANT_VH
  as select from zsim_stock   as stock
    inner join   zsim_product as product
      on product.product_id = stock.product_id
{
      @EndUserText.label: 'Product'
      @UI.lineItem: [ { position: 10 } ]
      @Search.defaultSearchElement: true
  key stock.product_id       as ProductId,

      @EndUserText.label: 'Plant'
      @UI.lineItem: [ { position: 30 } ]
  key stock.plant_id         as PlantId,

      @EndUserText.label: 'Name'
      @UI.lineItem: [ { position: 20 } ]
      @Search.defaultSearchElement: true
      product.product_name   as ProductName,

      @EndUserText.label: 'On Hand'
      @UI.lineItem: [ { position: 40 } ]
      stock.quantity_on_hand as QuantityOnHand
}
where stock.quantity_on_hand > 0
