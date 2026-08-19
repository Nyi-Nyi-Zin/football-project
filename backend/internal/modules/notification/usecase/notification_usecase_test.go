package usecase

import (
	"context"
	"testing"

	"betting-app/internal/modules/notification/domain"
	"betting-app/internal/shared/event"
)

type fakeNotificationRepo struct {
	created *domain.Notification
}

func (f *fakeNotificationRepo) Create(_ context.Context, notification *domain.Notification) error {
	f.created = notification
	return nil
}

func (f *fakeNotificationRepo) FindByID(_ context.Context, _ string) (*domain.Notification, error) {
	return nil, nil
}

func (f *fakeNotificationRepo) FindByUser(_ context.Context, _ string, _ bool, _, _ int) ([]*domain.Notification, int64, error) {
	return nil, 0, nil
}

func (f *fakeNotificationRepo) MarkAsRead(_ context.Context, _ string) error { return nil }
func (f *fakeNotificationRepo) MarkAllAsRead(_ context.Context, _ string) error {
	return nil
}
func (f *fakeNotificationRepo) GetUnreadCount(_ context.Context, _ string) (int64, error) {
	return 0, nil
}
func (f *fakeNotificationRepo) Delete(_ context.Context, _ string) error { return nil }

func TestSendNormalizesEmptyJSONBData(t *testing.T) {
	repo := &fakeNotificationRepo{}
	uc := NewNotificationUseCase(repo, event.NewBus())

	_, err := uc.Send(context.Background(), &domain.SendNotificationRequest{
		UserID:  "11111111-1111-1111-1111-111111111111",
		Type:    domain.NotificationTypeWithdrawal,
		Title:   "Withdrawal Request Submitted",
		Message: "Your withdrawal request is pending.",
	})
	if err != nil {
		t.Fatalf("send notification failed: %v", err)
	}
	if repo.created == nil {
		t.Fatal("expected notification to be persisted")
	}
	if repo.created.Data != "{}" {
		t.Fatalf("expected empty notification data to become {}, got %q", repo.created.Data)
	}
}
