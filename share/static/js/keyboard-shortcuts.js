jQuery(function() {
    var goBack = function() {
        window.history.back();
    };

    var goForward = function() {
        window.history.forward();
    };

    var goHome = function() {
        var homeLink = jQuery('a#home');
        window.location.href = homeLink.attr('href');
    };

    var simpleSearch = function() {
        var searchInput = jQuery('#simple-search').find('input');
        if (!searchInput.length) return;

        searchInput.focus();
        searchInput.select();

        return false; // prevent '/' character from being typed in search box
    };

    var openHelp = function() {
        var modal = jQuery('.modal');
        if (modal.length) {
            jQuery.modal.close();
            return;
        }

        jQuery.ajax({
            url: RT.Config.WebHomePath + "/Helpers/ShortcutHelp",
            success: showModal,
            error: function(xhr, reason) {
                // give the browser a chance to redraw the readout
                setTimeout(function () {
                    alert(loc_key("shortcut_help_error") + reason);
                }, 100);
            }
        });
    };

    var showModal = function(html) {
        jQuery("<div class='modal'></div>")
            .append(html).appendTo("body")
            .bind('modal:close', function(ev,modal) { modal.elm.remove(); })
            .modal();
    };

    Mousetrap.bind('g b', goBack);
    Mousetrap.bind('g f', goForward);
    Mousetrap.bind('g h', goHome);
    Mousetrap.bind('/', simpleSearch);
    Mousetrap.bind('?', openHelp);
});

jQuery(function() {
    // Only load these shortcuts if there is a ticket list on the page
    var hasTicketList = jQuery('table.ticket-list').length;
    if (!hasTicketList) return;

    var currentRow;

    var nextTicket = function() {
        var nextRow;
        var searchResultsTable = jQuery('.ticket-list.collection-as-table');
        if (!currentRow || !(nextRow = currentRow.next('tbody.list-item')).length) {
            nextRow = searchResultsTable.find('tbody.list-item').first();
        }
        setNewRow(nextRow);
    };

    var setNewRow = function(newRow) {
        if (currentRow) currentRow.removeClass('selected-row');
        currentRow = newRow;
        currentRow.addClass('selected-row');
        scrollToJQueryObject(currentRow);
    };

    var prevTicket = function() {
        var prevRow, searchResultsTable = jQuery('.ticket-list.collection-as-table');
        if (!currentRow || !(prevRow = currentRow.prev('tbody.list-item')).length) {
            prevRow = searchResultsTable.find('tbody.list-item').last();
        }
        setNewRow(prevRow);
    };

    var navigateToCurrentTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tbody').data('recordId');
        var ticketLink = generateTicketLink(ticketId);
        if (!ticketLink) return;

        window.location.href = ticketLink;
    };

    var generateTicketLink = function(ticketId) {
        if (!ticketId) return '';
        return RT.Config.WebHomePath + '/Ticket/Display.html?id=' + ticketId;
    };

    var toggleTicketCheckbox = function() {
        if (!currentRow) return;
        var ticketCheckBox = currentRow.find('input[type=checkbox]');
        if (!ticketCheckBox.length) return;
        ticketCheckBox.prop("checked", !ticketCheckBox.prop("checked"));
    };

    var replyToTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tbody').data('recordId');
        var replyLink = generateUpdateLink(ticketId, 'Respond');
        if (!replyLink) return;

        window.location.href = replyLink;
    };

    var generateUpdateLink = function(ticketId, action) {
        if (!ticketId) return '';
        return RT.Config.WebHomePath + '/Ticket/Update.html?Action=' + action + '&id=' + ticketId;
    };

    var commentOnTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tbody').data('recordId');
        var commentLink = generateUpdateLink(ticketId, 'Comment');
        if (!commentLink) return;

        window.location.href = commentLink;
    };

    Mousetrap.bind('j', nextTicket);
    Mousetrap.bind('k', prevTicket);
    Mousetrap.bind(['enter','o'], navigateToCurrentTicket);
    Mousetrap.bind('r', replyToTicket);
    Mousetrap.bind('c', commentOnTicket);
    Mousetrap.bind('x', toggleTicketCheckbox);
});

