@EndUserText.label: 'Stock Movement - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZSIM_C_STOCKMOVEMENT
  as projection on ZSIM_I_STOCKMOVEMENT
{
  key MovementId,
      ProductId,
      PlantId,
      MovementType,
      Quantity,
      StockAfter,
      Reference,
      CreatedBy,
      CreatedAt,

      /* Associations */
      _Stock   : redirected to parent ZSIM_C_STOCK,
      _Product : redirected to ZSIM_C_PRODUCT
}
