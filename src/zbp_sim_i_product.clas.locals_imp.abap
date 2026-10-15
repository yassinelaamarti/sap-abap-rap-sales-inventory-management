CLASS lhc_Product DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Product RESULT result.
ENDCLASS.

CLASS lhc_Product IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Aucune restriction pour le moment (DCL à ajouter plus tard)
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_Stock DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Stock RESULT result.
    METHODS receiveStock FOR MODIFY
      IMPORTING keys FOR ACTION Stock~receiveStock RESULT result.
ENDCLASS.

CLASS lhc_Stock IMPLEMENTATION.
  METHOD get_instance_authorizations.
    " Aucune restriction pour le moment (DCL à ajouter plus tard)
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).
  ENDMETHOD.

  METHOD receiveStock.

    DATA valid_keys LIKE keys.

    " 1. La quantité reçue doit être positive
    LOOP AT keys INTO DATA(key).
      IF key-%param-Quantity > 0.
        APPEND key TO valid_keys.
      ELSE.
        APPEND VALUE #( %tky = key-%tky ) TO failed-stock.
        APPEND VALUE #(
          %tky = key-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Received quantity must be positive' )
        ) TO reported-stock.
      ENDIF.
    ENDLOOP.
    CHECK valid_keys IS NOT INITIAL.

    " 2. Stock actuel
    READ ENTITIES OF zsim_i_product IN LOCAL MODE
      ENTITY Stock
        FIELDS ( QuantityOnHand )
        WITH CORRESPONDING #( valid_keys )
      RESULT DATA(stocks).

    " 3. Mise à jour du stock et création de la ligne d'historique, dans la même transaction
    MODIFY ENTITIES OF zsim_i_product IN LOCAL MODE
      ENTITY Stock
        UPDATE FIELDS ( QuantityOnHand LastUpdatedAt )
        WITH VALUE #( FOR s IN stocks
          LET qty = valid_keys[ ProductId = s-ProductId
                                PlantId   = s-PlantId ]-%param-Quantity IN
          ( %tky           = s-%tky
            QuantityOnHand = s-QuantityOnHand + qty
            LastUpdatedAt  = utclong_current( ) ) )

      ENTITY Stock
        CREATE BY \_Movements
        FIELDS ( MovementType Quantity StockAfter Reference CreatedBy CreatedAt )
        WITH VALUE #( FOR s IN stocks
          LET k = valid_keys[ ProductId = s-ProductId
                              PlantId   = s-PlantId ] IN
          ( %tky    = s-%tky
            %target = VALUE #( ( %cid         = |RECEIPT-{ s-ProductId }-{ s-PlantId }|
                                 MovementType = 'Receipt'
                                 Quantity     = k-%param-Quantity
                                 StockAfter   = s-QuantityOnHand + k-%param-Quantity
                                 Reference    = k-%param-Reference
                                 CreatedBy    = cl_abap_context_info=>get_user_technical_name( )
                                 CreatedAt    = utclong_current( ) ) ) ) ).

    " 4. Résultat renvoyé à l'interface
    READ ENTITIES OF zsim_i_product IN LOCAL MODE
      ENTITY Stock
        ALL FIELDS WITH CORRESPONDING #( valid_keys )
      RESULT DATA(updated_stocks).

    result = VALUE #( FOR u IN updated_stocks ( %tky = u-%tky %param = u ) ).

    reported-stock = VALUE #( BASE reported-stock
      FOR u IN updated_stocks
        ( %tky = u-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = |Stock received: { u-QuantityOnHand DECIMALS = 0 } units | &&
                              |now on hand at plant { u-PlantId }| ) ) ).

  ENDMETHOD.

ENDCLASS.
