/**
 * Visualforce page controller for OrgChart.page — merge fields only (no @RemoteAction).
 * If this class exposed @RemoteAction, Visualforce would auto-inject VFRemote/apex.js and hit InternalDialogs on headerless pages.
 * Chart data uses same-origin Apex REST (OrgChartRest).
 */
public with sharing class OrgChartPageController {
    public OrgChartPageController() {
    }

    public String getRootFederationIdJson() {
        return JSON.serialize(OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID);
    }
}
