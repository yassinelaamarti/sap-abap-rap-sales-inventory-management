@EndUserText.label: 'Plant'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZSIM_I_PLANT
  as select from zsim_plant
{
  key plant_id      as PlantId,
      plant_name    as PlantName,
      city          as City,
      country_code  as CountryCode
}
