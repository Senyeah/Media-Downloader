import { Component, OnInit, Inject } from '@angular/core';
import { Media } from './media';
import { MediaService } from './media.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  private media: Media[] = [];

  constructor(@Inject(MediaService) private mediaService) {

  }

  ngOnInit() {
    this.mediaService.media.subscribe(
      media => this.media = media
    );
  }
}
