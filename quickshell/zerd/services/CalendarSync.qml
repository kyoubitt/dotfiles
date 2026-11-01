pragma Singleton

import QtQuick
import Quickshell

// No external calendar: the faces see an empty agenda.
Singleton {
    function getEventsForDate(date: var): var { return [] }
    function getUpcomingEvents(days: int): var { return [] }
}
