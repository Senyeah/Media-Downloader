import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { MediaActionButtonComponent } from './media-action-button.component';

describe('MediaActionButtonComponent', () => {
  let component: MediaActionButtonComponent;
  let fixture: ComponentFixture<MediaActionButtonComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ MediaActionButtonComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(MediaActionButtonComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
