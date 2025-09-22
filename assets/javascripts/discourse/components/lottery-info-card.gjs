import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { on } from "@ember/modifier";  // 添加这行导入
import { i18n } from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";
import { formatDate } from "discourse/helpers/format-date";

export default class LotteryInfoCard extends Component {
  @service currentUser;
  @tracked timeRemaining = "";
  @tracked lockTimeRemaining = "";
  
  constructor() {
    super(...arguments);
    this.updateCountdown();
    this.countdownInterval = setInterval(() => {
      this.updateCountdown();
    }, 1000);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
  }

  get lotteryData() {
    return this.args.lotteryData;
  }

  get isRunning() {
    return this.lotteryData?.status === "running";
  }

  get isFinished() {
    return this.lotteryData?.status === "finished";
  }

  get isCancelled() {
    return this.lotteryData?.status === "cancelled";
  }

  get statusClass() {
    return `lottery-status-${this.lotteryData?.status || 'unknown'}`;
  }

  get statusIcon() {
    switch (this.lotteryData?.status) {
      case "running":
        return "clock";
      case "finished":
        return "trophy";
      case "cancelled":
        return "times";
      default:
        return "question";
    }
  }

  get statusText() {
    switch (this.lotteryData?.status) {
      case "running":
        return i18n("lottery.status.running");
      case "finished":
        return i18n("lottery.status.finished");
      case "cancelled":
        return i18n("lottery.status.cancelled");
      default:
        return i18n("lottery.status.unknown");
    }
  }

  get drawTimeFormatted() {
    if (!this.lotteryData?.draw_time) return "";
    return formatDate(new Date(this.lotteryData.draw_time), {
      format: "medium"
    });
  }

  get lotteryTypeText() {
    if (this.lotteryData?.lottery_type === "specified") {
      return i18n("lottery.type.specified_floors");
    }
    return i18n("lottery.type.random");
  }

  get specifiedFloorsText() {
    if (this.lotteryData?.specified_floors) {
      return this.lotteryData.specified_floors.split(',').join('、') + "楼";
    }
    return "";
  }

  get backupStrategyText() {
    if (this.lotteryData?.backup_strategy === "continue") {
      return i18n("lottery.backup_strategy.continue");
    }
    return i18n("lottery.backup_strategy.cancel");
  }

  get canEdit() {
    if (!this.isRunning || !this.currentUser) return false;
    
    const topic = this.args.topic;
    if (topic?.user_id !== this.currentUser.id) return false;
    
    return this.lockTimeRemaining && this.lockTimeRemaining !== "已锁定";
  }

  @action
  updateCountdown() {
    if (!this.lotteryData?.draw_time) return;
    
    const now = Date.now();
    const drawTime = new Date(this.lotteryData.draw_time).getTime();
    const lockDelay = (this.args.siteSettings?.lottery_post_lock_delay_minutes || 30) * 60 * 1000;
    const lockTime = drawTime - lockDelay;
    
    const timeUntilDraw = drawTime - now;
    if (timeUntilDraw > 0) {
      this.timeRemaining = this.formatTimeRemaining(timeUntilDraw);
    } else {
      this.timeRemaining = i18n("lottery.time.draw_time_passed");
    }
    
    if (this.isRunning) {
      const timeUntilLock = lockTime - now;
      if (timeUntilLock > 0) {
        this.lockTimeRemaining = this.formatTimeRemaining(timeUntilLock);
      } else {
        this.lockTimeRemaining = i18n("lottery.time.locked");
      }
    }
  }

  formatTimeRemaining(milliseconds) {
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
      return i18n("lottery.time.days_remaining", { count: days });
    } else if (hours > 0) {
      return i18n("lottery.time.hours_remaining", { count: hours });
    } else if (minutes > 0) {
      return i18n("lottery.time.minutes_remaining", { count: minutes });
    } else {
      return i18n("lottery.time.seconds_remaining", { count: seconds });
    }
  }

  @action
  editLottery() {
    if (this.args.onEdit) {
      this.args.onEdit();
    }
  }

  <template>
    <div class="lottery-info-card {{this.statusClass}}">
      <div class="lottery-header">
        <div class="lottery-status">
          {{icon this.statusIcon class="status-icon"}}
          <span class="status-text">{{this.statusText}}</span>
        </div>
        {{#if this.canEdit}}
          <button class="btn btn-small lottery-edit-btn" {{on "click" this.editLottery}}>
            {{icon "pencil-alt"}}
            {{i18n "lottery.actions.edit"}}
          </button>
        {{/if}}
      </div>

      <div class="lottery-content">
        <h3 class="lottery-title">{{this.lotteryData.title}}</h3>
        
        <div class="lottery-details">
          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.prize"}}:</span>
            <span class="detail-value">{{this.lotteryData.prize_description}}</span>
          </div>

          {{#if this.lotteryData.image_url}}
            <div class="detail-item">
              <span class="detail-label">{{i18n "lottery.details.image"}}:</span>
              <div class="lottery-image">
                <img src={{this.lotteryData.image_url}} alt="奖品图片" class="prize-image" />
              </div>
            </div>
          {{/if}}

          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.draw_time"}}:</span>
            <span class="detail-value">{{this.drawTimeFormatted}}</span>
          </div>

          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.lottery_type"}}:</span>
            <span class="detail-value">
              {{this.lotteryTypeText}}
              {{#if this.specifiedFloorsText}}
                ({{this.specifiedFloorsText}})
              {{/if}}
            </span>
          </div>

          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.winner_count"}}:</span>
            <span class="detail-value">{{this.lotteryData.winner_count}}人</span>
          </div>

          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.min_participants"}}:</span>
            <span class="detail-value">{{this.lotteryData.min_participants}}人</span>
          </div>

          <div class="detail-item">
            <span class="detail-label">{{i18n "lottery.details.backup_strategy"}}:</span>
            <span class="detail-value">{{this.backupStrategyText}}</span>
          </div>

          {{#if this.lotteryData.additional_notes}}
            <div class="detail-item">
              <span class="detail-label">{{i18n "lottery.details.additional_notes"}}:</span>
              <span class="detail-value">{{this.lotteryData.additional_notes}}</span>
            </div>
          {{/if}}
        </div>

        {{#if this.isRunning}}
          <div class="lottery-countdown">
            <div class="countdown-item">
              <span class="countdown-label">{{i18n "lottery.countdown.draw_time"}}:</span>
              <span class="countdown-value">{{this.timeRemaining}}</span>
            </div>
            {{#if this.canEdit}}
              <div class="countdown-item edit-warning">
                <span class="countdown-label">{{i18n "lottery.countdown.edit_deadline"}}:</span>
                <span class="countdown-value">{{this.lockTimeRemaining}}</span>
              </div>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.isFinished}}
          <div class="lottery-winners">
            <h4 class="winners-title">{{icon "trophy"}} {{i18n "lottery.winners.title"}}</h4>
            {{#if this.args.winnersData}}
              <ul class="winners-list">
                {{#each this.args.winnersData as |winner index|}}
                  <li class="winner-item">
                    <span class="winner-rank">{{add index 1}}.</span>
                    <span class="winner-username">@{{winner.username}}</span>
                    <span class="winner-floor">({{winner.floor}}楼)</span>
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.isCancelled}}
          <div class="lottery-cancelled">
            <div class="cancelled-message">
              {{icon "exclamation-triangle"}}
              {{i18n "lottery.cancelled.message"}}
            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
