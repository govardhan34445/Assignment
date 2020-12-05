function notification (response){
    if(response){
         if(response.result == 1) {
            alertify.success(response.message); 
            window.location.reload();
            // $("#grid").jsGrid("loadData");
         }
         if(response.result == 0 ) {
            alertify.error(response.message); 
         }
         if(response.result == -1 ) {
            alertify.warning(response.message); 
         }
   } else {
        alertify.error("No response from server");
   }
}

alertify.set('notifier','position', 'top-right');

function load_jsgrid(options) {
    var $grid = $('#' + options.grid_name);
    var control_field = {
        type: "control",
        modeSwitchButton: false,
        itemTemplate: function(value, item) {
            var $result = $([]);
            if(item.is_active==1) {
                var $customEditButton = $("<button>").attr({class: "customGridEditbutton jsgrid-button jsgrid-edit-button"})
                  .click(function(e) {
                        var newForm = $('<form>', {
                            'action': '/?edit=person&id=' + item.id,
                            'method': 'post'
                        });
                        newForm.appendTo('body').submit();
                        e.stopPropagation();
                  });
                $result = $result.add($customEditButton);
                $result = $result.add(this._createDeleteButton(item));
            }
            return $result;
        },
        headerTemplate: function(value, item) {
            var $result = $([]);
            var $customAddButton = $("<button>").attr({class: "jsgrid-header-cell jsgrid-control-field jsgrid-align-center btn btn-success btn-block"}).html("Add")
                  .click(function(e) {
                      window.location.href = '/?edit=person&id=New';
                        e.stopPropagation();
                  });
                $result = $result.add($customAddButton);
                return $result;
        }
    };
    options.fields.push(control_field);

    $grid.jsGrid({
        autoload: true,
        height: "auto",
        width: "100%",
        editing: true,
        paging: true,
        pageSize: 10,
        sorting: true,
        filtering: true,
        sorter: "string",
        pageButtonCount: 15,
        noDataContent: "No Data",
        deleteButtonTooltip: "Delete",
        searchButtonTooltip: "Search",
        clearFilterButtonTooltip: "Clear filter",
        confirmDeleting: false,
        controller: options.db,
        rowClass: function(item, itemIndex) {
            return item.is_active == 0 ? 'bg-red' : '';
        },
        rowClick: function(args) {
            if(args.item.is_active == 1){
                showDetailsDialog("Edit", args.item);
            }
        },
        fields: options.fields,
        onItemDeleting: function (args) {
            if (!args.item.deleteConfirmed) { // custom property for confirmation
                args.cancel = true; // cancel deleting
                alertify.confirm("The "+ options.entity_name +" \"" + args.item[options.delete_cnf_field] + "\" will be removed. Are you sure?",
                  function(){
                      args.item.deleteConfirmed = true;
                      $grid.jsGrid('deleteItem', args.item); //call deleting once more in callback
              }).setHeader('<em> Confirm Delete </em>');
            }
        },
    });

    var saveClient = function(client, isNew) {
        var save_options = {};
        for (field of options.form_fields) {
            save_options[field] = $('#'+field).val();
        }
        $.extend(client, save_options);
        $grid.jsGrid(isNew ? "insertItem" : "updateItem", client);
        $("#detailsDialog").dialog("close");
    };

    $("#detailsForm").validate({
       "rules": options.validation_rules,
       "messages": options.validation_messages,
        submitHandler: function() {
            formSubmitHandler();
        }
    });
    var formSubmitHandler = $.noop;

    var showDetailsDialog = function(dialogType, client) {
        //set fields value for update model
        for (field of options.form_fields) {
            if ( client[field] === true ) {
                client[field] = 1;
            }
            if ( client[field] === false ) {
                client[field] = 0;
            }
            $('#' + field).val(client[field]);
        }

        formSubmitHandler = function() {
            saveClient(client, dialogType === "Add");
        };
        $("#detailsDialog").dialog("option", "title", dialogType + " Client").dialog("open");
    };
    $("#detailsDialog").dialog({
        autoOpen: false,
        width: 400,
        close: function() {
            $("#detailsForm").validate().resetForm();
            $("#detailsForm").find(".error").removeClass("error");
        }
    });
}

function build_ajax_request (options) {
    $.ajax({
        type: options.type,
        url: options.route,
        contentType: "application/json; charset=utf-8",
        data: JSON.stringify(options.params),
        dataType: "JSON",
        error : function(xhr, textStatus, errorThrown) {
            alertify.error(errorThrown); 
        },
        success:function(response){
            notification(response);
            this.clients.push(insertingClient);
        }
    });
}