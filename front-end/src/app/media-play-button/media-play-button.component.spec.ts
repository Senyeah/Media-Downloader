import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { MediaPlayButtonComponent } from './media-play-button.component';

describe('MediaPlayButtonComponent', () => {
  let component: MediaPlayButtonComponent;
  let fixture: ComponentFixture<MediaPlayButtonComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ MediaPlayButtonComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(MediaPlayButtonComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
