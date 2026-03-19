@IsTest
private class OrgChartServiceTest {
    @IsTest
    static void hierarchy_returnsSyntheticOrganizationRoot() {
        OrgChartService.HierarchyPayload p = OrgChartService.getHierarchy(false);
        System.assertNotEquals(null, p.hierarchy, 'Hierarchy root should exist');
        System.assertEquals(
            OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID,
            p.hierarchy.federationId
        );
        System.assertNotEquals(null, p.hierarchy.directReports);
        System.assertNotEquals(null, p.createdDate);
    }

    @IsTest
    static void search_shortQuery_returnsEmpty() {
        List<OrgChartService.SearchHitDTO> hits = OrgChartService.searchUsers('a', 10, false);
        System.assertEquals(0, hits.size());
    }

    @IsTest
    static void detail_blankKey_throws() {
        try {
            OrgChartService.getUserDetail('');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
