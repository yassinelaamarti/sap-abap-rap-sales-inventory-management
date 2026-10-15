@EndUserText.label: 'Stock - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZSIM_C_STOCK
  as projection on ZSIM_I_STOCK
{
  key ProductId,
  key PlantId,
      QuantityOnHand,
      LastUpdatedAt,
      AvailableStock,
      RiskCriticality,

      /* Associations */
      _Product   : redirected to parent ZSIM_C_PRODUCT,
      _Plant,
      _Movements : redirected to composition child ZSIM_C_STOCKMOVEMENT
}
