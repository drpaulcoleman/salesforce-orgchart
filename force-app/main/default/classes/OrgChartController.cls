/**
 * @AuraEnabled entry points for Lightning Web Components.
 */
public with sharing class OrgChartController {
    @AuraEnabled(cacheable=false)
    public static OrgChartService.HierarchyPayload getHierarchy(Boolean fteOnly) {
        try {
            return OrgChartService.getHierarchy(fteOnly);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<OrgChartService.SearchHitDTO> searchUsers(String query, Integer limitSize, Boolean fteOnly) {
        try {
            return OrgChartService.searchUsers(query, limitSize, fteOnly);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static OrgChartService.DetailDTO getUserDetail(String federationId) {
        try {
            return OrgChartService.getUserDetail(federationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static OrgChartService.MeDTO getCurrentUserContext() {
        return OrgChartService.getMe();
    }

    @AuraEnabled(cacheable=true)
    public static String getSyntheticRootFederationId() {
        return OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID;
    }
}
