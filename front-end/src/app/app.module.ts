import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { MediaPickerComponent } from './media-picker/media-picker.component';
import { MediaSectionComponent } from './media-section/media-section.component';
import { MediaPlayButtonComponent } from './media-play-button/media-play-button.component';

@NgModule({
  declarations: [
    AppComponent,
    MediaPickerComponent,
    MediaSectionComponent,
    MediaPlayButtonComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
