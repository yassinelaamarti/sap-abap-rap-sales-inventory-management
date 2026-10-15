@EndUserText.label: 'Plant - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZSIM_C_PLANT
  as projection on ZSIM_I_PLANT
{
  key PlantId,
      PlantName,
      City,
      CountryCode
}
