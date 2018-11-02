import { Component, OnInit, Input } from '@angular/core';
import { Media } from '../media';

@Component({
  selector: 'app-media-picker',
  templateUrl: './media-picker.component.html',
  styleUrls: ['./media-picker.component.scss']
})
export class MediaPickerComponent implements OnInit {

  @Input() private source: Media[] = [];

  constructor() { }

  ngOnInit() {

  }

  play(episode: Media) {
    console.log(episode);
  }

}
