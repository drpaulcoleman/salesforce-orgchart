/**
 * Builds org hierarchy from User.ManagerId and exposes DTOs compatible with the D3 org chart UI.
 */
public with sharing class OrgChartService {
    public static final String SYNTHETIC_ROOT_FEDERATION_ID = 'organization@internal';

    public class HierarchyPayload {
        @AuraEnabled
        public NodeDTO hierarchy { get; set; }
        @AuraEnabled
        public Datetime createdDate { get; set; }
    }

    public class NodeDTO {
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String federationId { get; set; }
        @AuraEnabled
        public String title { get; set; }
        @AuraEnabled
        public String smallPhotoUrl { get; set; }
        @AuraEnabled
        public List<NodeDTO> directReports { get; set; }

        public NodeDTO() {
            directReports = new List<NodeDTO>();
        }
    }

    public class SearchHitDTO {
        @AuraEnabled
        public String federationId { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String title { get; set; }
        @AuraEnabled
        public String smallPhotoUrl { get; set; }
    }

    public class DetailDTO {
        @AuraEnabled
        public String orgUserId { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String title { get; set; }
        @AuraEnabled
        public String pronoun { get; set; }
        @AuraEnabled
        public String slackUserId { get; set; }
        @AuraEnabled
        public String mobilePhone { get; set; }
        @AuraEnabled
        public String email { get; set; }
        @AuraEnabled
        public String location { get; set; }
        @AuraEnabled
        public String mediumPhotoUrl { get; set; }
        @AuraEnabled
        public String largePhotoUrl { get; set; }
        /** Lightning record page for this User (current org). */
        @AuraEnabled
        public String userRecordUrl { get; set; }
    }

    public class MeDTO {
        @AuraEnabled
        public String slackEnterpriseId { get; set; }
    }

    public static HierarchyPayload getHierarchy(Boolean fteOnly) {
        List<User> rows = queryUsers(fteOnly);
        Map<Id, User> byId = new Map<Id, User>(rows);

        Map<Id, NodeDTO> nodes = new Map<Id, NodeDTO>();
        for (User u : rows) {
            nodes.put(u.Id, userToNode(u));
        }

        Set<Id> attached = new Set<Id>();
        List<NodeDTO> topLevel = new List<NodeDTO>();

        for (User u : rows) {
            NodeDTO n = nodes.get(u.Id);
            if (
                u.ManagerId != null &&
                nodes.containsKey(u.ManagerId) &&
                isValidManagerChain(u.Id, u.ManagerId, byId)
            ) {
                nodes.get(u.ManagerId).directReports.add(n);
                attached.add(u.Id);
            }
        }

        for (User u : rows) {
            if (!attached.contains(u.Id)) {
                topLevel.add(nodes.get(u.Id));
            }
        }

        NodeDTO root = new NodeDTO();
        root.name = 'Organization';
        root.federationId = SYNTHETIC_ROOT_FEDERATION_ID;
        root.title = '';
        root.directReports = topLevel;

        HierarchyPayload payload = new HierarchyPayload();
        payload.hierarchy = root;
        payload.createdDate = System.now();
        return payload;
    }

    public static List<SearchHitDTO> searchUsers(String term, Integer limitSize, Boolean fteOnly) {
        if (String.isBlank(term) || term.length() < 2) {
            return new List<SearchHitDTO>();
        }
        if (limitSize == null || limitSize < 1) {
            limitSize = 25;
        }
        limitSize = Math.min(limitSize, 100);

        String searchPattern = '%' + term.trim() + '%';
        Integer lim = limitSize;
        String fte = (fteOnly == true) ? ' AND UserType = \'Standard\' ' : ' ';
        String q =
            'SELECT Id, Name, Email, Username, Title, SmallPhotoUrl ' +
            'FROM User WHERE IsActive = true ' +
            fte +
            ' AND (Name LIKE :searchPattern OR Email LIKE :searchPattern OR Username LIKE :searchPattern OR Title LIKE :searchPattern) ' +
            'ORDER BY Name LIMIT :lim';

        List<User> found = Database.query(q);
        List<SearchHitDTO> out = new List<SearchHitDTO>();
        for (User u : found) {
            SearchHitDTO h = new SearchHitDTO();
            h.federationId = federationIdFor(u);
            h.name = u.Name;
            h.title = u.Title;
            h.smallPhotoUrl = u.SmallPhotoUrl;
            out.add(h);
        }
        return out;
    }

    public static DetailDTO getUserDetail(String federationKey) {
        if (String.isBlank(federationKey)) {
            throw new AuraHandledException('User key is required.');
        }
        User u = findUserByFederationKey(federationKey);
        if (u == null) {
            throw new AuraHandledException('User not found or not accessible.');
        }

        DetailDTO d = new DetailDTO();
        d.orgUserId = u.Id;
        d.name = u.Name;
        d.title = u.Title;
        d.pronoun = String.isNotBlank(u.AboutMe)
            ? u.AboutMe.length() > 120
                  ? u.AboutMe.substring(0, 120) + '…'
                  : u.AboutMe
            : null;
        d.slackUserId = null;
        d.mobilePhone = u.MobilePhone;
        d.email = u.Email;
        d.location = buildLocation(u);
        d.mediumPhotoUrl = u.MediumPhotoUrl;
        d.largePhotoUrl = u.MediumPhotoUrl;
        d.userRecordUrl =
            Url.getOrgDomainUrl().toExternalForm() + '/lightning/r/User/' + u.Id + '/view';
        return d;
    }

    public static MeDTO getMe() {
        MeDTO m = new MeDTO();
        m.slackEnterpriseId = null;
        return m;
    }

    private static List<User> queryUsers(Boolean fteOnly) {
        String q =
            'SELECT Id, Name, Email, Username, Title, ManagerId, SmallPhotoUrl, MediumPhotoUrl ' +
            'FROM User WHERE IsActive = true ' + userTypeClause(fteOnly) + ' ORDER BY Name';
        return Database.query(q);
    }

    private static String userTypeClause(Boolean fteOnly) {
        if (fteOnly == true) {
            return ' AND UserType = \'Standard\' ';
        }
        return ' ';
    }

    private static NodeDTO userToNode(User u) {
        NodeDTO n = new NodeDTO();
        n.name = u.Name;
        n.federationId = federationIdFor(u);
        n.title = u.Title;
        n.smallPhotoUrl = u.SmallPhotoUrl;
        n.directReports = new List<NodeDTO>();
        return n;
    }

    public static String federationIdFor(User u) {
        if (String.isNotBlank(u.Email)) {
            return u.Email;
        }
        if (String.isNotBlank(u.Username)) {
            return u.Username;
        }
        return u.Id;
    }

    private static String buildLocation(User u) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(u.City)) {
            parts.add(u.City);
        }
        if (String.isNotBlank(u.State)) {
            parts.add(u.State);
        }
        if (String.isNotBlank(u.Country)) {
            parts.add(u.Country);
        }
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    /**
     * Rejects manager links that would create a cycle in the active user set.
     */
    private static Boolean isValidManagerChain(Id userId, Id managerId, Map<Id, User> byId) {
        Set<Id> seen = new Set<Id>();
        Id cur = managerId;
        Integer hops = 0;
        while (cur != null && byId.containsKey(cur) && hops < 100) {
            if (cur == userId) {
                return false;
            }
            if (seen.contains(cur)) {
                return false;
            }
            seen.add(cur);
            cur = byId.get(cur).ManagerId;
            hops++;
        }
        return true;
    }

    private static User findUserByFederationKey(String key) {
        String trimmed = key.trim();
        if (trimmed.length() == 15 || trimmed.length() == 18) {
            try {
                Id uid = (Id) trimmed;
                return [
                    SELECT
                        Id,
                        Name,
                        Email,
                        Username,
                        Title,
                        AboutMe,
                        MobilePhone,
                        MediumPhotoUrl,
                        City,
                        State,
                        Country
                    FROM User
                    WHERE Id = :uid AND IsActive = TRUE
                    LIMIT 1
                ];
            } catch (Exception e) {
                // not a valid Id, fall through
            }
        }

        List<User> byEmail = [
            SELECT
                Id,
                Name,
                Email,
                Username,
                Title,
                AboutMe,
                MobilePhone,
                MediumPhotoUrl,
                City,
                State,
                Country
            FROM User
            WHERE Email = :trimmed AND IsActive = TRUE
            LIMIT 1
        ];
        if (!byEmail.isEmpty()) {
            return byEmail[0];
        }

        List<User> byUsername = [
            SELECT
                Id,
                Name,
                Email,
                Username,
                Title,
                AboutMe,
                MobilePhone,
                MediumPhotoUrl,
                City,
                State,
                Country
            FROM User
            WHERE Username = :trimmed AND IsActive = TRUE
            LIMIT 1
        ];
        return byUsername.isEmpty() ? null : byUsername[0];
    }
}
