pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    readonly property int cpu: Math.round(Svc.ResourceUsage.cpuUsage * 100)
    readonly property int ramPercent: Math.round(Svc.ResourceUsage.memoryUsedPercentage * 100)
    readonly property int temp: Math.round(Svc.ResourceUsage.cpuTemp)
    readonly property int diskPercent: Math.round(Svc.ResourceUsage.diskUsedPercentage * 100)
    property int subscribers: 0
    function subscribe() {
        subscribers++;
        if (subscribers === 1) Svc.ResourceUsage.keepAlive();
    }
    function unsubscribe() {
        if (subscribers <= 0) return;
        subscribers--;
        if (subscribers === 0) Svc.ResourceUsage.releaseKeepAlive();
    }
}
