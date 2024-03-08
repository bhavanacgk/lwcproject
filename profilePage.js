import { LightningElement, api} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ProfilePage extends LightningElement {
    activeSectionMessage = '';

    handleToggleSection(event) {
        this.activeSectionMessage =
            'Open section name:  ' + event.detail.openSections;
    }

    @api recordId;
    handleSubmit(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message:  'Account updated successfully!',
                variant: 'success',
            })
        );
        console.log('onsubmit event recordEditForm'+ event.detail.fields);
    }
    handleSuccess(event) {
        console.log('onsuccess event recordEditForm', event.detail.id);
    }
    handleChange(event) {
        console.log('You selected an owner: ' + event.detail.value[0]);
    }
}

