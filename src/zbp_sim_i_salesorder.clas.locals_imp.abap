*"* Aide : recalcul du montant total d'une commande (somme des montants de ses lignes)
CLASS lcl_totals DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_order_key,
             order_id TYPE zsim_so-order_id,
             is_draft TYPE abp_behv_flag,
           END OF ty_order_key,
           tt_order_key TYPE STANDARD TABLE OF ty_order_key WITH DEFAULT KEY.

    CLASS-METHODS recalculate IMPORTING keys TYPE tt_order_key.
ENDCLASS.


CLASS lcl_totals IMPLEMENTATION.

  METHOD recalculate.

    DATA(unique_keys) = keys.
    SORT unique_keys BY order_id is_draft.
    DELETE ADJACENT DUPLICATES FROM unique_keys COMPARING order_id is_draft.
    CHECK unique_keys IS NOT INITIAL.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OrderId )
        WITH VALUE #( FOR k IN unique_keys ( OrderId = k-order_id %is_draft = k-is_draft ) )
      RESULT DATA(orders).
    CHECK orders IS NOT INITIAL.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( NetAmount Currency )
        WITH CORRESPONDING #( orders )
      RESULT DATA(items).

    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( TotalAmount Currency )
        WITH VALUE #( FOR o IN orders
          ( %tky        = o-%tky
            TotalAmount = REDUCE decfloat34(
                            INIT s = CONV decfloat34( 0 )
                            FOR i IN items
                            WHERE ( OrderId = o-OrderId AND %is_draft = o-%is_draft )
                            NEXT s = s + i-NetAmount )
            Currency    = VALUE #( items[ OrderId   = o-OrderId
                                          %is_draft = o-%is_draft ]-Currency OPTIONAL ) ) ).

  ENDMETHOD.

ENDCLASS.


*"* ---------------------------------------------------------------
*"* Saver : le stock physique baisse quand une commande passe à "Shipped"
*"* ---------------------------------------------------------------
CLASS lsc_zsim_i_salesorder DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_zsim_i_salesorder IMPLEMENTATION.

  METHOD save_modified.

    " Commandes qui viennent de passer à Shipped dans cet enregistrement
    DATA shipped_ids TYPE STANDARD TABLE OF zsim_so-order_id WITH EMPTY KEY.

    LOOP AT update-salesorder INTO DATA(upd).
      IF upd-%control-Status = if_abap_behv=>mk-on AND upd-Status = 'S'.
        APPEND upd-OrderId TO shipped_ids.
      ENDIF.
    ENDLOOP.
    CHECK shipped_ids IS NOT INITIAL.

    " Lignes de ces commandes, avec le site de la commande
    SELECT soi~order_id, soi~product_id, so~plant_id, soi~quantity
      FROM zsim_so_item AS soi
      INNER JOIN zsim_so AS so ON so~order_id = soi~order_id
      FOR ALL ENTRIES IN @shipped_ids
      WHERE soi~order_id = @shipped_ids-table_line
      INTO TABLE @DATA(items).

    LOOP AT items INTO DATA(item).

      " Diminution du stock physique (accès direct à la table : phase de sauvegarde)
      UPDATE zsim_stock
        SET quantity_on_hand = quantity_on_hand - @item-quantity,
            last_updated_at  = @( utclong_current( ) )
        WHERE product_id = @item-product_id
          AND plant_id   = @item-plant_id.
      CHECK sy-subrc = 0.

      " Historique : mouvement de sortie, avec le stock après mouvement
      SELECT SINGLE quantity_on_hand
        FROM zsim_stock
        WHERE product_id = @item-product_id
          AND plant_id   = @item-plant_id
        INTO @DATA(stock_after).

      TRY.
          DATA(movement) = VALUE zsim_stock_mvt(
            client        = sy-mandt
            movement_id   = cl_system_uuid=>create_uuid_x16_static( )
            product_id    = item-product_id
            plant_id      = item-plant_id
            movement_type = 'Shipment'
            quantity      = 0 - item-quantity
            stock_after   = stock_after
            reference     = item-order_id
            created_by    = cl_abap_context_info=>get_user_technical_name( )
            created_at    = utclong_current( ) ).
          INSERT zsim_stock_mvt FROM @movement.
        CATCH cx_uuid_error.
          " L'historique est une information : l'expédition n'est pas bloquée
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


*"* ---------------------------------------------------------------
*"* SalesOrder
*"* ---------------------------------------------------------------
CLASS lhc_SalesOrder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR SalesOrder RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrder RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE SalesOrder.

    METHODS earlynumbering_cba_Items FOR NUMBERING
      IMPORTING entities FOR CREATE SalesOrder\_Items.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setInitialStatus.

    METHODS syncItemsPlant FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~syncItemsPlant.

    METHODS recalculateTotal FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~recalculateTotal.

    METHODS validateOrderDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateOrderDate.

    METHODS confirmOrder FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~confirmOrder RESULT result.

    METHODS shipOrder FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~shipOrder RESULT result.

    METHODS cancelOrder FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~cancelOrder RESULT result.

ENDCLASS.


CLASS lhc_SalesOrder IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Aucune restriction pour le moment (DCL à ajouter plus tard)
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).
  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    " Modification / suppression : seulement tant que la commande est New (ou en brouillon)
    " Confirm : New | Ship : Confirmed | Cancel : New ou Confirmed (jamais sur un brouillon)
    result = VALUE #( FOR order IN orders
      LET is_draft = xsdbool( order-%is_draft = if_abap_behv=>mk-on )
          is_new   = xsdbool( order-Status = 'N' )
          is_conf  = xsdbool( order-Status = 'C' )
      IN
      ( %tky = order-%tky

        %update = COND #( WHEN is_draft = abap_true OR is_new = abap_true
                          THEN if_abap_behv=>fc-o-enabled
                          ELSE if_abap_behv=>fc-o-disabled )

        %delete = COND #( WHEN is_draft = abap_true OR is_new = abap_true
                          THEN if_abap_behv=>fc-o-enabled
                          ELSE if_abap_behv=>fc-o-disabled )

        %action-Edit = COND #( WHEN is_new = abap_true
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )

        %action-confirmOrder = COND #( WHEN is_draft = abap_false AND is_new = abap_true
                                       THEN if_abap_behv=>fc-o-enabled
                                       ELSE if_abap_behv=>fc-o-disabled )

        %action-shipOrder = COND #( WHEN is_draft = abap_false AND is_conf = abap_true
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )

        %action-cancelOrder = COND #( WHEN is_draft = abap_false
                                       AND ( is_new = abap_true OR is_conf = abap_true )
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


  METHOD earlynumbering_create.
    DATA lv_last TYPE i.

    " 1. Instances qui ont déjà un OrderId (activation du brouillon) : clé reprise telle quelle
    LOOP AT entities INTO DATA(entity) WHERE OrderId IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-salesorder.
    ENDLOOP.

    " 2. Nouvelles instances sans OrderId
    DATA(entities_wo_id) = entities.
    DELETE entities_wo_id WHERE OrderId IS NOT INITIAL.
    CHECK entities_wo_id IS NOT INITIAL.

    " Numéros existants : commandes actives + brouillons
    SELECT order_id FROM zsim_so INTO TABLE @DATA(lt_ids).
    SELECT orderid AS order_id FROM zsim_so_d APPENDING TABLE @lt_ids.

    LOOP AT lt_ids INTO DATA(ls_id).
      DATA(lv_txt) = |{ ls_id-order_id }|.
      IF strlen( lv_txt ) > 3 AND lv_txt(3) = 'SO-' AND lv_txt+3 CO '0123456789'.
        lv_last = nmax( val1 = lv_last val2 = CONV i( lv_txt+3 ) ).
      ENDIF.
    ENDLOOP.

    LOOP AT entities_wo_id INTO DATA(new_entity).
      lv_last += 1.
      APPEND VALUE #(
        %cid      = new_entity-%cid
        %is_draft = new_entity-%is_draft
        OrderId   = |SO-{ lv_last WIDTH = 4 ALIGN = RIGHT PAD = '0' }|
      ) TO mapped-salesorder.
    ENDLOOP.
  ENDMETHOD.


  METHOD earlynumbering_cba_Items.
    DATA lv_last TYPE i.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
      FROM CORRESPONDING #( entities )
      LINK DATA(existing_items).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<order>).

      lv_last = 0.

      " Plus grand numéro de ligne déjà existant pour cette commande
      LOOP AT existing_items INTO DATA(link) WHERE source-OrderId = <order>-OrderId.
        lv_last = nmax( val1 = lv_last val2 = CONV i( link-target-ItemNumber ) ).
      ENDLOOP.

      " ... et parmi les lignes reçues qui ont déjà un numéro
      LOOP AT <order>-%target ASSIGNING FIELD-SYMBOL(<known>) WHERE ItemNumber IS NOT INITIAL.
        lv_last = nmax( val1 = lv_last val2 = CONV i( <known>-ItemNumber ) ).
      ENDLOOP.

      " Numérotation des nouvelles lignes uniquement
      LOOP AT <order>-%target ASSIGNING FIELD-SYMBOL(<new_item>).
        APPEND CORRESPONDING #( <new_item> ) TO mapped-salesorderitem
          ASSIGNING FIELD-SYMBOL(<mapped>).
        IF <new_item>-ItemNumber IS INITIAL.
          lv_last += 10.
          <mapped>-ItemNumber = lv_last.
        ENDIF.
      ENDLOOP.

    ENDLOOP.
  ENDMETHOD.


  METHOD setInitialStatus.
    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'N' ) ).
  ENDMETHOD.


  METHOD syncItemsPlant.
    " Quand le site de la commande change, ses lignes suivent (le filtre des produits en dépend)

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( PlantId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( PlantId )
        WITH CORRESPONDING #( orders )
      RESULT DATA(items).
    CHECK items IS NOT INITIAL.

    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        UPDATE FIELDS ( PlantId )
        WITH VALUE #( FOR i IN items
          ( %tky    = i-%tky
            PlantId = VALUE #( orders[ OrderId   = i-OrderId
                                       %is_draft = i-%is_draft ]-PlantId OPTIONAL ) ) ).

  ENDMETHOD.


  METHOD recalculateTotal.
    " Exécutée par l'action Prepare (enregistrement) : recalcul du total de chaque commande
    lcl_totals=>recalculate( VALUE #( FOR k IN keys
                                      ( order_id = k-OrderId is_draft = k-%is_draft ) ) ).
  ENDMETHOD.


  METHOD validateOrderDate.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OrderDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT orders INTO DATA(order).
      IF order-OrderDate > today.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #(
          %tky = order-%tky
          %msg = new_message(
                   id       = '00'
                   number   = '001'
                   severity = if_abap_behv_message=>severity-error
                   v1       = 'Order date cannot be in the future' )
          %element-OrderDate = if_abap_behv=>mk-on
        ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD confirmOrder.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( Quantity )
        WITH CORRESPONDING #( orders )
      RESULT DATA(items).

    DATA confirm_orders LIKE orders.

    LOOP AT orders INTO DATA(order).

      IF order-Status <> 'N'.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #(
          %tky = order-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Order { order-OrderId }: only new orders can be confirmed| )
        ) TO reported-salesorder.

      ELSEIF NOT line_exists( items[ OrderId   = order-OrderId
                                     %is_draft = order-%is_draft ] ).
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #(
          %tky = order-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Order { order-OrderId } has no items| )
        ) TO reported-salesorder.

      ELSE.
        APPEND order TO confirm_orders.
      ENDIF.

    ENDLOOP.

    CHECK confirm_orders IS NOT INITIAL.

    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN confirm_orders ( %tky = o-%tky Status = 'C' ) ).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( confirm_orders )
      RESULT DATA(updated_orders).

    result = VALUE #( FOR u IN updated_orders ( %tky = u-%tky %param = u ) ).

    reported-salesorder = VALUE #( BASE reported-salesorder
      FOR u IN updated_orders
        ( %tky = u-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = |Order { u-OrderId } confirmed| ) ) ).

  ENDMETHOD.


  METHOD shipOrder.

    DATA on_hand TYPE zsim_stock-quantity_on_hand.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status PlantId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( ProductId Quantity )
        WITH CORRESPONDING #( orders )
      RESULT DATA(items).

    DATA ship_orders LIKE orders.

    LOOP AT orders INTO DATA(order).

      " 1. L'expédition n'est possible que depuis le statut Confirmed
      IF order-Status <> 'C'.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #(
          %tky = order-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Order { order-OrderId } must be confirmed before shipping| )
        ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      " 2. Le stock physique doit couvrir chaque ligne
      DATA(stock_ok) = abap_true.

      LOOP AT items INTO DATA(item) WHERE OrderId   = order-OrderId
                                      AND %is_draft = order-%is_draft.

        CLEAR on_hand.
        SELECT SINGLE quantity_on_hand
          FROM zsim_stock
          WHERE product_id = @item-ProductId
            AND plant_id   = @order-PlantId
          INTO @on_hand.
        DATA(found) = xsdbool( sy-subrc = 0 ).

        DATA(needed) = REDUCE decfloat34(
                         INIT s = CONV decfloat34( 0 )
                         FOR l IN items
                         WHERE ( OrderId   = order-OrderId
                             AND %is_draft = order-%is_draft
                             AND ProductId = item-ProductId )
                         NEXT s = s + l-Quantity ).

        IF found = abap_false OR on_hand < needed.
          stock_ok = abap_false.
          APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
          APPEND VALUE #(
            %tky = order-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = |Not enough physical stock for product { item-ProductId } | &&
                                |at plant { order-PlantId }| )
          ) TO reported-salesorder.
          EXIT.
        ENDIF.

      ENDLOOP.

      IF stock_ok = abap_true.
        APPEND order TO ship_orders.
      ENDIF.

    ENDLOOP.

    CHECK ship_orders IS NOT INITIAL.

    " Le stock physique est diminué à l'enregistrement (voir save_modified)
    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN ship_orders ( %tky = o-%tky Status = 'S' ) ).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( ship_orders )
      RESULT DATA(updated_orders).

    result = VALUE #( FOR u IN updated_orders ( %tky = u-%tky %param = u ) ).

    reported-salesorder = VALUE #( BASE reported-salesorder
      FOR u IN updated_orders
        ( %tky = u-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = |Order { u-OrderId } shipped, physical stock updated| ) ) ).

  ENDMETHOD.


  METHOD cancelOrder.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA cancel_orders LIKE orders.

    LOOP AT orders INTO DATA(order).

      IF order-Status = 'N' OR order-Status = 'C'.
        APPEND order TO cancel_orders.
      ELSE.
        DATA(reason) = COND string(
          WHEN order-Status = 'X'
          THEN |Order { order-OrderId } is already cancelled|
          ELSE |Order { order-OrderId } cannot be cancelled in its current status| ).

        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #(
          %tky = order-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = reason )
        ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.

    CHECK cancel_orders IS NOT INITIAL.

    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR o IN cancel_orders ( %tky = o-%tky Status = 'X' ) ).

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( cancel_orders )
      RESULT DATA(updated_orders).

    result = VALUE #( FOR u IN updated_orders ( %tky = u-%tky %param = u ) ).

    reported-salesorder = VALUE #( BASE reported-salesorder
      FOR u IN updated_orders
        ( %tky = u-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-success
                   text     = |Order { u-OrderId } cancelled| ) ) ).

  ENDMETHOD.

ENDCLASS.


*"* ---------------------------------------------------------------
*"* SalesOrderItem
*"* ---------------------------------------------------------------
CLASS lhc_SalesOrderItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS validateQuantities FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateQuantities.

    METHODS checkStockAvailability FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~checkStockAvailability.

    METHODS calculateAmounts FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~calculateAmounts.

    METHODS setItemPlant FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~setItemPlant.

    METHODS recalculateParentTotal FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrderItem~recalculateParentTotal.

ENDCLASS.


CLASS lhc_SalesOrderItem IMPLEMENTATION.

  METHOD validateQuantities.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #(
          %tky = item-%tky
          %msg = new_message(
                   id       = '00'
                   number   = '001'
                   severity = if_abap_behv_message=>severity-error
                   v1       = 'Quantity must be positive' )
          %element-Quantity = if_abap_behv=>mk-on
        ) TO reported-salesorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD checkStockAvailability.
    " Contrôle BLOQUANT : une commande ne peut pas dépasser le stock disponible du site

    DATA on_hand   TYPE zsim_stock-quantity_on_hand.
    DATA committed TYPE zsim_so_item-quantity.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ProductId Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).
    CHECK items IS NOT INITIAL.

    " Site de chaque commande
    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem BY \_SalesOrder
        FIELDS ( PlantId )
        WITH CORRESPONDING #( items )
      RESULT DATA(orders).

    " Toutes les lignes des commandes concernées (pour additionner un même produit)
    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Items
        FIELDS ( ProductId Quantity )
        WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    LOOP AT items INTO DATA(item).

      DATA(plant_id) = VALUE #( orders[ OrderId   = item-OrderId
                                        %is_draft = item-%is_draft ]-PlantId OPTIONAL ).
      IF plant_id IS INITIAL OR item-ProductId IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR: on_hand, committed.

      " Stock physique du produit sur le site
      SELECT SINGLE quantity_on_hand
        FROM zsim_stock
        WHERE product_id = @item-ProductId
          AND plant_id   = @plant_id
        INTO @on_hand.
      DATA(no_stock_record) = xsdbool( sy-subrc <> 0 ).

      " Quantités engagées par les AUTRES commandes New ou Confirmed
      SELECT SINGLE FROM zsim_so_item AS soi
        INNER JOIN zsim_so AS so ON so~order_id = soi~order_id
        FIELDS SUM( soi~quantity )
        WHERE soi~product_id = @item-ProductId
          AND so~plant_id    = @plant_id
          AND so~status     IN ( 'N', 'C' )
          AND so~order_id   <> @item-OrderId
        INTO @committed.

      " Quantité demandée pour ce produit dans CETTE commande
      DATA(requested) = REDUCE decfloat34(
                          INIT s = CONV decfloat34( 0 )
                          FOR l IN all_items
                          WHERE ( OrderId   = item-OrderId
                              AND %is_draft = item-%is_draft
                              AND ProductId = item-ProductId )
                          NEXT s = s + l-Quantity ).

      DATA(available) = on_hand - committed.

      IF requested > available.

        DATA(msg_text) = COND string(
          WHEN no_stock_record = abap_true
          THEN |Product { item-ProductId } has no stock at plant { plant_id }|
          ELSE |Product { item-ProductId }: requested { requested DECIMALS = 0 } | &&
               |exceeds available stock { available DECIMALS = 0 } at plant { plant_id }| ).

        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.

        APPEND VALUE #(
          %tky  = item-%tky
          %path = VALUE #( salesorder-%is_draft = item-%is_draft
                           salesorder-OrderId   = item-OrderId )
          %element-Quantity = if_abap_behv=>mk-on
          %msg  = new_message_with_text(
                    severity = if_abap_behv_message=>severity-error
                    text     = msg_text )
        ) TO reported-salesorderitem.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD calculateAmounts.

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ProductId Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    IF items IS NOT INITIAL.

      " Prix unitaire et devise des produits concernés
      SELECT product_id, unit_price, currency
        FROM zsim_product
        FOR ALL ENTRIES IN @items
        WHERE product_id = @items-ProductId
        INTO TABLE @DATA(products).

      DATA item_updates TYPE TABLE FOR UPDATE zsim_i_salesorder\\SalesOrderItem.

      LOOP AT items INTO DATA(item).
        DATA(product) = VALUE #( products[ product_id = item-ProductId ] OPTIONAL ).
        APPEND VALUE #( %tky      = item-%tky
                        NetAmount = item-Quantity * product-unit_price
                        Currency  = product-currency ) TO item_updates.
      ENDLOOP.

      MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
          UPDATE FIELDS ( NetAmount Currency )
          WITH item_updates.

    ENDIF.

    " Total de la commande parente (la clé du parent est dans la clé de la ligne)
    lcl_totals=>recalculate( VALUE #( FOR k IN keys
                                      ( order_id = k-OrderId is_draft = k-%is_draft ) ) ).

  ENDMETHOD.


  METHOD setItemPlant.
    " À la création d'une ligne : reprend le site de la commande (filtre des produits)

    READ ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem BY \_SalesOrder
        FIELDS ( PlantId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      LINK DATA(links).

    MODIFY ENTITIES OF zsim_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        UPDATE FIELDS ( PlantId )
        WITH VALUE #( FOR l IN links
          ( %tky    = l-source-%tky
            PlantId = VALUE #( orders[ OrderId   = l-target-OrderId
                                       %is_draft = l-target-%is_draft ]-PlantId OPTIONAL ) ) ).

  ENDMETHOD.


  METHOD recalculateParentTotal.
    " Déclenchée par la suppression d'une ligne : la clé de la ligne contient celle de la commande
    lcl_totals=>recalculate( VALUE #( FOR k IN keys
                                      ( order_id = k-OrderId is_draft = k-%is_draft ) ) ).
  ENDMETHOD.

ENDCLASS.
