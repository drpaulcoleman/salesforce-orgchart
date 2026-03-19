@IsTest
private class OrgChartPageControllerTest {
    @IsTest
    static void rootFederationIdJson_containsSyntheticRootConstant() {
        OrgChartPageController c = new OrgChartPageController();
        System.assert(
            c.getRootFederationIdJson().contains(OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID),
            'Expected JSON-serialized root federation id'
        );
    }
}
