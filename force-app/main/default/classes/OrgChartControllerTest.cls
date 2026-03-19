@IsTest
private class OrgChartControllerTest {
    @IsTest
    static void syntheticRootConstant_exposed() {
        System.assertEquals(
            'organization@internal',
            OrgChartController.getSyntheticRootFederationId()
        );
    }

    @IsTest
    static void getHierarchy_returnsPayload() {
        OrgChartService.HierarchyPayload p = OrgChartController.getHierarchy(false);
        System.assertNotEquals(null, p.hierarchy);
    }

    @IsTest
    static void search_shortQuery_returnsEmpty() {
        System.assertEquals(0, OrgChartController.searchUsers('x', 10, false).size());
    }
}
