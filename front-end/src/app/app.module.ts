import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { MediaPickerComponent } from './media-picker/media-picker.component';
import { MediaSectionComponent } from './media-section/media-section.component';
import { MediaActionButtonComponent } from './media-action-button/media-action-button.component';

@NgModule({
  declarations: [
    AppComponent,
    MediaPickerComponent,
    MediaSectionComponent,
    MediaActionButtonComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
