import { LightningElement } from 'lwc';

/**
 * Hosts the full D3 org chart Visualforce page in an iframe (same session cookie).
 * Add this component to a Lightning App Page or Home Page.
 */
export default class OrgChartShell extends LightningElement {
    vfPageUrl = '/apex/OrgChart';
}
