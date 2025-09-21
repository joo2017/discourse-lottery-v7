import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import DModalCancel from "discourse/components/d-modal-cancel";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class LotteryFormModal extends Component {
  @service dialog;
  @service siteSettings;
  @service currentUser;
  
  @tracked title = "";
  @tracked prizeDescription = "";
  @tracked uploadedImage = null;
  @tracked drawTime = "";
  @tracked winnerCount = 1;
  @tracked specifiedFloors = "";
  @tracked minParticipants = this.siteSettings.lottery_min_participants_global || 5;
  @tracked backupStrategy = "continue";
  @tracked additionalNotes = "";
  @tracked isSubmitting = false;
  @tracked errors = {};

  get minDateTime() {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    return tomorrow.toISOString().slice(0, 16);
  }

  get globalMinParticipants() {
    return this.siteSettings.lottery_min_participants_global || 1;
  }

  @action
  updateTitle(event) {
    this.title = event.target.value;
    this.clearFieldError('title');
  }

  @action
  updatePrizeDescription(event) {
    this.prizeDescription = event.target.value;
    this.clearFieldError('prizeDescription');
  }

  @action
  updateDrawTime(event) {
    this.drawTime = event.target.value;
    this.clearFieldError('drawTime');
  }

  @action
  updateWinnerCount(event) {
    this.winnerCount = parseInt(event.target.value) || 1;
    this.clearFieldError('winnerCount');
  }

  @action
  updateSpecifiedFloors(event) {
    this.specifiedFloors = event.target.value;
    this.clearFieldError('specifiedFloors');
  }

  @action
  updateMinParticipants(event) {
    const value = parseInt(event.target.value) || 1;
    this.minParticipants = value;
    
    // 实时验证最小参与人数
    if (value < this.globalMinParticipants) {
      this.errors.minParticipants = i18n("lottery.form.min_participants_error", {
        min: this.globalMinParticipants
      });
    } else {
      this.clearFieldError('minParticipants');
    }
  }

  @action
  updateBackupStrategy(event) {
    this.backupStrategy = event.target.value;
  }

  @action
  updateAdditionalNotes(event) {
    this.additionalNotes = event.target.value;
  }

  @action
  onImageUploaded(upload) {
    this.uploadedImage = upload;
  }

  @action
  clearFieldError(fieldName) {
    if (this.errors[fieldName]) {
      delete this.errors[fieldName];
      this.errors = { ...this.errors };
    }
  }

  @action
  validateForm() {
    this.errors = {};
    let isValid = true;

    if (!this.title.trim()) {
      this.errors.title = i18n("lottery.form.title_required");
      isValid = false;
    }

    if (!this.prizeDescription.trim()) {
      this.errors.prizeDescription = i18n("lottery.form.prize_description_required");
      isValid = false;
    }

    if (!this.drawTime) {
      this.errors.drawTime = i18n("lottery.form.draw_time_required");
      isValid = false;
    } else {
      const drawDate = new Date(this.drawTime);
      const now = new Date();
      if (drawDate <= now) {
        this.errors.drawTime = i18n("lottery.form.draw_time_future");
        isValid = false;
      }
    }

    if (this.winnerCount < 1) {
      this.errors.winnerCount = i18n("lottery.form.winner_count_min");
      isValid = false;
    } else if (this.winnerCount > 100) {
      this.errors.winnerCount = i18n("lottery.form.winner_count_max");
      isValid = false;
    }

    if (this.minParticipants < this.globalMinParticipants) {
      this.errors.minParticipants = i18n("lottery.form.min_participants_error", {
        min: this.globalMinParticipants
      });
      isValid = false;
    }

    // 验证指定楼层格式
    if (this.specifiedFloors.trim()) {
      const floors = this.specifiedFloors.split(',').map(f => f.trim());
      for (let floor of floors) {
        const floorNum = parseInt(floor);
        if (isNaN(floorNum) || floorNum < 2) {
          this.errors.specifiedFloors = i18n("lottery.form.specified_floors_invalid");
          isValid = false;
          break;
        }
      }
    }

    return isValid;
  }

  @action
  async submitForm() {
    if (!this.validateForm()) {
      return;
    }

    this.isSubmitting = true;

    try {
      const topicId = this.args.model.topic?.id;
      if (!topicId) {
        throw new Error("Topic ID not found");
      }

      const data = {
        topic_id: topicId,
        lottery_title: this.title,
        lottery_prize_description: this.prizeDescription,
        lottery_draw_time: this.drawTime,
        lottery_winner_count: this.winnerCount,
        lottery_min_participants: this.minParticipants,
        lottery_backup_strategy: this.backupStrategy,
        lottery_additional_notes: this.additionalNotes
      };

      if (this.uploadedImage) {
        data.lottery_image_upload_id = this.uploadedImage.id;
      }

      if (this.specifiedFloors.trim()) {
        data.lottery_specified_floors = this.specifiedFloors;
      }

      const result = await ajax("/lottery/create", {
        type: "POST",
        data: data
      });

      this.dialog.alert(i18n("lottery.form.success_message"));
      this.args.closeModal();
      
      // 刷新页面以显示抽奖信息
      window.location.reload();

    } catch (error) {
      console.error("抽奖创建错误:", error);
      
      if (error.jqXHR?.responseJSON?.errors) {
        this.errors = { general: error.jqXHR.responseJSON.errors.join(", ") };
      } else if (error.jqXHR?.responseJSON?.error) {
        this.errors = { general: error.jqXHR.responseJSON.error };
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.isSubmitting = false;
    }
  }

  @action
  cancel() {
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "lottery.modal_title"}}
      @closeModal={{@closeModal}}
      class="lottery-form-modal"
    >
      <:body>
        <form class="lottery-form">
          {{#if this.errors.general}}
            <div class="alert alert-error">{{this.errors.general}}</div>
          {{/if}}

          <div class="form-group">
            <label for="lottery-title" class="form-label">
              {{i18n "lottery.form.title_label"}}
              <span class="required">*</span>
            </label>
            <Input
              @type="text"
              @value={{this.title}}
              {{on "input" this.updateTitle}}
              placeholder={{i18n "lottery.form.title_placeholder"}}
              id="lottery-title"
              class="form-control {{if this.errors.title 'error'}}"
              maxlength="255"
            />
            {{#if this.errors.title}}
              <div class="error-message">{{this.errors.title}}</div>
            {{/if}}
          </div>

          <div class="form-group">
            <label for="lottery-prize" class="form-label">
              {{i18n "lottery.form.prize_description_label"}}
              <span class="required">*</span>
            </label>
            <textarea
              {{on "input" this.updatePrizeDescription}}
              id="lottery-prize"
              class="form-control {{if this.errors.prizeDescription 'error'}}"
              rows="3"
              placeholder={{i18n "lottery.form.prize_description_placeholder"}}
            >{{this.prizeDescription}}</textarea>
            {{#if this.errors.prizeDescription}}
              <div class="error-message">{{this.errors.prizeDescription}}</div>
            {{/if}}
          </div>

          {{#if this.siteSettings.lottery_allow_image_upload}}
            <div class="form-group">
              <label class="form-label">
                {{i18n "lottery.form.image_label"}}
              </label>
              <UppyImageUploader
                @id="lottery-image"
                @type="composer"
                @uploadUrl="/uploads.json"
                @done={{this.onImageUploaded}}
                class="image-uploader"
              />
              {{#if this.uploadedImage}}
                <div class="uploaded-image-preview">
                  <img src={{this.uploadedImage.url}} alt="奖品图片预览" class="preview-image" />
                </div>
              {{/if}}
            </div>
          {{/if}}

          <div class="form-group">
            <label for="lottery-draw-time" class="form-label">
              {{i18n "lottery.form.draw_time_label"}}
              <span class="required">*</span>
            </label>
            <Input
              @type="datetime-local"
              @value={{this.drawTime}}
              {{on "input" this.updateDrawTime}}
              id="lottery-draw-time"
              class="form-control {{if this.errors.drawTime 'error'}}"
              min={{this.minDateTime}}
            />
            {{#if this.errors.drawTime}}
              <div class="error-message">{{this.errors.drawTime}}</div>
            {{/if}}
          </div>

          <div class="form-row">
            <div class="form-group half-width">
              <label for="lottery-winner-count" class="form-label">
                {{i18n "lottery.form.winner_count_label"}}
                <span class="required">*</span>
              </label>
              <Input
                @type="number"
                @value={{this.winnerCount}}
                {{on "input" this.updateWinnerCount}}
                id="lottery-winner-count"
                class="form-control {{if this.errors.winnerCount 'error'}}"
                min="1"
                max="100"
              />
              <div class="form-hint">{{i18n "lottery.form.winner_count_hint"}}</div>
              {{#if this.errors.winnerCount}}
                <div class="error-message">{{this.errors.winnerCount}}</div>
              {{/if}}
            </div>

            <div class="form-group half-width">
              <label for="lottery-min-participants" class="form-label">
                {{i18n "lottery.form.min_participants_label"}}
                <span class="required">*</span>
              </label>
              <Input
                @type="number"
                @value={{this.minParticipants}}
                {{on "input" this.updateMinParticipants}}
                id="lottery-min-participants"
                class="form-control {{if this.errors.minParticipants 'error'}}"
                min={{this.globalMinParticipants}}
              />
              <div class="form-hint">{{i18n "lottery.form.min_participants_hint" min=this.globalMinParticipants}}</div>
              {{#if this.errors.minParticipants}}
                <div class="error-message">{{this.errors.minParticipants}}</div>
              {{/if}}
            </div>
          </div>

          <div class="form-group">
            <label for="lottery-specified-floors" class="form-label">
              {{i18n "lottery.form.specified_floors_label"}}
            </label>
            <Input
              @type="text"
              @value={{this.specifiedFloors}}
              {{on "input" this.updateSpecifiedFloors}}
              placeholder={{i18n "lottery.form.specified_floors_placeholder"}}
              id="lottery-specified-floors"
              class="form-control {{if this.errors.specifiedFloors 'error'}}"
            />
            <div class="form-hint">{{i18n "lottery.form.specified_floors_hint"}}</div>
            {{#if this.errors.specifiedFloors}}
              <div class="error-message">{{this.errors.specifiedFloors}}</div>
            {{/if}}
          </div>

          <div class="form-group">
            <label for="lottery-backup-strategy" class="form-label">
              {{i18n "lottery.form.backup_strategy_label"}}
              <span class="required">*</span>
            </label>
            <select
              {{on "change" this.updateBackupStrategy}}
              id="lottery-backup-strategy"
              class="form-control"
            >
              <option value="continue" selected={{eq this.backupStrategy "continue"}}>
                {{i18n "lottery.form.backup_strategy_continue"}}
              </option>
              <option value="cancel" selected={{eq this.backupStrategy "cancel"}}>
                {{i18n "lottery.form.backup_strategy_cancel"}}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label for="lottery-notes" class="form-label">
              {{i18n "lottery.form.additional_notes_label"}}
            </label>
            <textarea
              {{on "input" this.updateAdditionalNotes}}
              id="lottery-notes"
              class="form-control"
              rows="3"
              placeholder={{i18n "lottery.form.additional_notes_placeholder"}}
            >{{this.additionalNotes}}</textarea>
          </div>
        </form>
      </:body>

      <:footer>
        <DButton
          @action={{this.submitForm}}
          @disabled={{this.isSubmitting}}
          class="btn-primary lottery-submit"
        >
          {{#if this.isSubmitting}}
            {{icon "spinner" class="loading-icon"}}
          {{/if}}
          {{i18n "lottery.form.submit"}}
        </DButton>
        
        <DModalCancel @close={{this.cancel}} />
      </:footer>
    </DModal>
  </template>
}
