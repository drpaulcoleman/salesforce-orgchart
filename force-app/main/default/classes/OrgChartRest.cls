/**
 * REST API for static SPA or external hosts (same-origin session cookie).
 * Base URL: /services/apexrest/OrgChart/v1?action=...
 */
@RestResource(urlMapping='/OrgChart/v1')
global with sharing class OrgChartRest {
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        try {
            Map<String, String> p = req.params;
            String action = p.get('action');
            if (String.isBlank(action)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Missing action parameter."}');
                return;
            }

            if (action.equalsIgnoreCase('hierarchy')) {
                Boolean fte = parseBool(p.get('fteOnly'));
                OrgChartService.HierarchyPayload payload = OrgChartService.getHierarchy(fte);
                res.responseBody = Blob.valueOf(JSON.serialize(payload));
                return;
            }

            if (action.equalsIgnoreCase('search')) {
                String q = p.get('q');
                Integer lim = 25;
                if (p.containsKey('limit') && String.isNotBlank(p.get('limit'))) {
                    lim = Integer.valueOf(p.get('limit'));
                }
                Boolean fte = parseBool(p.get('fteOnly'));
                List<OrgChartService.SearchHitDTO> hits = OrgChartService.searchUsers(q, lim, fte);
                res.responseBody = Blob.valueOf(JSON.serialize(hits));
                return;
            }

            if (action.equalsIgnoreCase('detail')) {
                String key = p.get('federationId');
                if (String.isBlank(key)) {
                    key = p.get('id');
                }
                OrgChartService.DetailDTO d = OrgChartService.getUserDetail(key);
                res.responseBody = Blob.valueOf(JSON.serialize(d));
                return;
            }

            if (action.equalsIgnoreCase('me')) {
                OrgChartService.MeDTO m = OrgChartService.getMe();
                res.responseBody = Blob.valueOf(JSON.serialize(m));
                return;
            }

            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Unknown action."}');
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                '{"error":"' + escapeJson(e.getMessage()) + '"}'
            );
        }
    }

    private static Boolean parseBool(String v) {
        if (String.isBlank(v)) {
            return false;
        }
        return v.equalsIgnoreCase('true') || v.equals('1');
    }

    private static String escapeJson(String s) {
        if (s == null) {
            return '';
        }
        return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ');
    }
}
